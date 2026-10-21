// Evaluate the scheduler payload without invoking tools or sending messages.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const source = fs.readFileSync(require('node:path').join(__dirname, '..', 'top_supervisor.js'), 'utf8');
const Script = Object.getPrototypeOf(async function() {}).constructor;
async function run(observed, previous = {}) {
  let result;
  let calls = 0;
  await new Script('exec', 'trigger', 'json', source)(async input => {
    calls++;
    assert.equal(input.timeoutSeconds, 20);
    return {stdout: JSON.stringify(observed)};
  }, {state: previous}, value => { result = value; });
  assert.equal(calls, 1);
  return result;
}
(async () => {
  const healthy = await run({stage:'s', started:1, status:'running'});
  assert.equal(healthy.notify, undefined);
  const first = await run({stage:'s', started:1, status:'blocked', reason:'no_new_evidence'}, healthy.state);
  assert.ok(first.notify);
  const second = await run({stage:'s', started:1, status:'blocked', reason:'no_new_evidence'}, first.state);
  assert.equal(second.notify, undefined);
  const resumed = await run({stage:'s', started:2, status:'blocked', reason:'command_timeout'}, second.state);
  assert.ok(resumed.notify);
  const done = await run({stage:'s', started:2, status:'done'}, resumed.state);
  assert.equal(done.notify, undefined);
  console.log('Supervisor: healthy silence, one alert, dedupe, new incident, terminal silence PASS');
})().catch(error => { console.error(error); process.exitCode = 1; });
