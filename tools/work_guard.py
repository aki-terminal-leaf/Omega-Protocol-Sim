#!/usr/bin/env python3
"""Bounded project stages; native scheduler calls `check` without an LLM loop."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_STATE = ROOT / subprocess.check_output(['git', 'rev-parse', '--git-path', 'top-work-guard.json'], cwd=ROOT, text=True).strip()


def read(path):
    return json.loads(path.read_text()) if path.exists() else {'status': 'idle'}


def write(path, state):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n')
    temp.replace(path)


def assess(state, now):
    if state.get('status') != 'running':
        return state
    reason = None
    if now >= state['deadline']:
        reason = 'stage_budget_exhausted'
    elif now - state['last_progress'] >= state['stall_seconds']:
        reason = 'no_new_evidence'
    if reason:
        state.update(status='blocked', reason=reason)
    return state


def emit(state):
    print(json.dumps(state, ensure_ascii=False), flush=True)


def group_members(group):
    """Return live members of our private POSIX session, ignoring exited zombies."""
    members = []
    for entry in Path('/proc').iterdir():
        if not entry.name.isdigit():
            continue
        try:
            # comm can contain spaces and parentheses; fields follow the LAST ).
            fields = (entry / 'stat').read_text().rsplit(')', 1)[1].split()
            if int(fields[2]) == group and fields[0] not in ('Z', 'X'):
                members.append(int(entry.name))
        except (OSError, ValueError, IndexError):
            continue
    return members


def terminate(child):
    # The session/group belongs to this command, including descendants whose
    # leader has already exited successfully. Never kill by process name.
    members = group_members(child.pid)
    if members:
        try:
            os.killpg(child.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        deadline = time.monotonic() + 3
        while group_members(child.pid) and time.monotonic() < deadline:
            child.poll()
            time.sleep(.05)
        if group_members(child.pid):
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
    if child.poll() is None:
        child.wait(timeout=3)
    deadline = time.monotonic() + .5
    while group_members(child.pid) and time.monotonic() < deadline:
        time.sleep(.02)
    return {'group': child.pid, 'signalled_pids': members,
            'remaining_live_pids': group_members(child.pid)}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--state', type=Path, default=DEFAULT_STATE)
    sub = p.add_subparsers(dest='action', required=True)
    b = sub.add_parser('begin'); b.add_argument('stage')
    b.add_argument('--budget', type=int, default=1500)
    b.add_argument('--stall', type=int, default=900)
    b.add_argument('--reason', default='')
    run = sub.add_parser('run'); run.add_argument('label')
    run.add_argument('--timeout', type=int, default=600)
    proof = sub.add_parser('progress'); proof.add_argument('evidence', type=Path)
    sub.add_parser('finish'); sub.add_parser('check')
    argv = sys.argv[1:]; command_args = []
    if '--' in argv:
        split = argv.index('--'); command_args = argv[split + 1:]; argv = argv[:split]
    args = p.parse_args(argv); path = args.state.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    # Short state transactions; a second lock below owns the entire command.
    def transact(fn):
        with open(str(path) + '.lock', 'a+') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            state = fn(read(path)); write(path, state)
            return state
    now = time.time()
    if args.action == 'begin':
        def begin(state):
            state = assess(state, now)
            if state.get('status') == 'running':
                raise SystemExit('An existing stage must finish or be explicitly blocked first')
            resuming = state.get('status') == 'blocked'
            if resuming:
                if args.stage != state.get('stage'):
                    raise SystemExit('Blocked: resume the same exact stage; renaming cannot clear its ledger')
                if not args.reason.strip():
                    raise SystemExit('Blocked: record a changed approach with --reason before resuming')
            if not 1 <= args.budget <= 1500 or not 1 <= args.stall <= 900:
                raise SystemExit('Maximum stage 1500s; maximum no-evidence interval 900s')
            if resuming:
                # A new bounded attempt retains the stage's circuit breaker and
                # evidence ledger. The reason records an approach, not proof.
                history = state.get('recovery_history', [])[-9:]
                history.append({'resumed': now,
                                'blocked_reason': state.get('reason', '')[:1000],
                                'prior_resume_reason': state.get('resume_reason', '')[:1000],
                                'resume_reason': args.reason[:1000]})
                state['recovery_history'] = history
                state.pop('reason', None)
                state.setdefault('failure_counts', {})
                state.setdefault('proof_hashes', [])
            else:
                state = {'failure_counts': {}, 'proof_hashes': []}
            state.update(stage=args.stage, status='running', started=now,
                         deadline=now + args.budget, last_progress=now,
                         stall_seconds=args.stall, resume_reason=args.reason)
            return state
        emit(transact(begin)); return
    if args.action == 'check':
        emit(transact(lambda s: assess(s, now))); return
    state = transact(lambda s: assess(s, now))
    if state.get('status') != 'running':
        emit(state); raise SystemExit(2)
    if args.action == 'progress':
        evidence = args.evidence.resolve()
        if not evidence.is_file() or evidence == path:
            raise SystemExit('Evidence must be an existing result or changed source file')
        digest = hashlib.sha256(evidence.read_bytes()).hexdigest()
        def progress(s):
            s = assess(s, time.time())
            if s['status'] != 'running' or digest in s['proof_hashes']:
                raise SystemExit('Blocked or unchanged evidence: progress was not renewed')
            s['proof_hashes'].append(digest); s['last_progress'] = time.time()
            s['evidence'] = str(evidence); return s
        emit(transact(progress)); return
    if args.action == 'finish':
        emit(transact(lambda s: dict(s, status='done', finished=time.time()))); return
    command = command_args
    if not command or not 1 <= args.timeout <= 600:
        raise SystemExit('Command required; maximum command timeout 600s')
    owner = open(str(path) + '.command.lock', 'a+')
    try:
        fcntl.flock(owner, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit('Another guarded command is already running')
    log_dir = path.parent / 'top-work-guard-logs'; log_dir.mkdir(exist_ok=True)
    label = re.sub(r'[^a-zA-Z0-9_-]', '_', args.label)
    log = log_dir / (label + '-' + str(time.time_ns()) + '.log')
    timed_out = False; child = None; cleanup = {}
    def interrupted(_signum, _frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        with log.open('w') as output:
            try:
                child = subprocess.Popen(command, cwd=ROOT, stdout=output,
                                         stderr=subprocess.STDOUT, start_new_session=True)
            except OSError as error:
                emit(transact(lambda s: dict(s, status='blocked', reason='command_launch_failed',
                                           launch_error=str(error), log=str(log))))
                raise SystemExit(1)
            start = time.monotonic()
            while child.poll() is None:
                current = transact(lambda s: assess(s, time.time()))
                if current.get('status') != 'running' or current.get('stage') != state['stage']:
                    timed_out = True; terminate(child); break
                if time.monotonic() - start >= args.timeout:
                    timed_out = True; terminate(child); break
                time.sleep(.2)
    except KeyboardInterrupt:
        emit(transact(lambda s: dict(s, status='blocked', reason='wrapper_interrupted')))
        raise SystemExit(130)
    finally:
        if child is not None:
            cleanup = terminate(child)
            transact(lambda s: dict(s, last_cleanup=cleanup))
    text = log.read_text(errors='replace')
    script_error = any(x in text for x in ['SCRIPT ERROR', 'Parse Error', 'Compile Error'])
    success = (child.returncode == 0 and not timed_out and not script_error
               and not cleanup.get('remaining_live_pids'))
    def result(s):
        s['last_command'] = {'label': args.label, 'exit': child.returncode,
                             'log': str(log), 'timeout': timed_out, 'ok': success,
                             'cleanup': cleanup}
        if timed_out:
            s.update(status='blocked', reason=s.get('reason', 'command_timeout'))
        elif not success:
            fingerprint = hashlib.sha256((str(child.returncode) + re.sub(r'\b\d+(?:\.\d+)?\b', '#', text[-4000:])).encode()).hexdigest()
            count = s['failure_counts'].get(fingerprint, 0) + 1
            s['failure_counts'][fingerprint] = count
            if count >= 3:
                s.update(status='blocked', reason='same_failure_three_times')
        return s
    emit(transact(result)); raise SystemExit(0 if success else 1)


if __name__ == '__main__':
    main()
