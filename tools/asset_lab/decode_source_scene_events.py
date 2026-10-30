"""Source-only C018/C196 contracts. No target resolver, clock or engine basis."""
import copy
import hashlib
import math
import struct


def f32(value):
    try:
        return struct.unpack('<f', struct.pack('<f', value))[0]
    except OverflowError:
        return math.copysign(math.inf, value)


def scalar(value):
    value = f32(value)
    return {'bits': struct.pack('<f', value).hex(),
            'status': 'nan' if math.isnan(value) else ('infinite' if math.isinf(value) else 'finite'),
            'value': value if math.isfinite(value) else None}


def divide(a, b):
    if math.isnan(a) or math.isnan(b) or (a == 0 and b == 0) or (math.isinf(a) and math.isinf(b)):
        return scalar(math.nan)
    if b == 0:
        return scalar(math.copysign(math.inf, math.copysign(1, a) * math.copysign(1, b)))
    return scalar(a / b)


def identity(graph, actor, track, event):
    return [graph['input_sha256'], graph['tmlb_offset'], actor['id'], actor['offset'],
            track['id'], track['offset'], event['id'], event['offset']]


def records(graph):
    for g in graph['graphs']:
        for a in g['actors']:
            for t in a['tracks']:
                for e in t['entries']:
                    yield {'namespace': identity(g, a, t, e), 'source_event': copy.deepcopy(e)}


def decode(record):
    out = copy.deepcopy(record)
    e = out['source_event']
    if e['tag'] not in ('C018', 'C196'):
        raise ValueError('unsupported tag: ' + e['tag'])
    ns = out['namespace']
    if len(ns) != 8 or len(ns[0]) != 64 or any(type(x) is not int or x < 0 for x in ns[1:]):
        raise ValueError('namespace')
    raw = bytes.fromhex(e['raw_hex'])
    if len(raw) != 56 or hashlib.sha256(raw).hexdigest() != e['sha256']:
        raise ValueError('raw length/hash')
    if (raw[:4].decode() != e['tag'] or struct.unpack_from('<I', raw, 4)[0] != 56 or e['size'] != 56
            or struct.unpack_from('<HHH', raw, 8) != (e['id'], e['time_u16'], e['duration_u16']) or ns[6:] != [e['id'], e['offset']]):
        raise ValueError('framing')
    out['raw_words_le'] = [raw[i:i+4].hex() for i in range(0, 56, 4)]
    out['provenance'] = 'native-contracts.md + PARENT_CORRECTIONS.md; finite reference arithmetic, not native bit equivalence'
    if e['tag'] == 'C018':
        values = struct.unpack_from('<9f', raw, 20)
        if not all(map(math.isfinite, values)):
            raise ValueError('nonfinite C018; raw retained by caller')
        out.update(position=list(values[:3]), euler=list(values[3:6]), archived_scale=list(values[6:]))
    else:
        selector, numerator, denominator, initial, later, threshold = struct.unpack_from('<IffIIi', raw, 20)
        if selector not in (0, 1):
            raise ValueError('unsupported selector')
        out.update(selector=selector, numerator=scalar(numerator), denominator=scalar(denominator),
                   ratio=divide(numerator, denominator), initial_arg=initial, later_arg=later,
                   threshold=threshold, threshold_f32=scalar(threshold))
    return out


def descriptor(size, fields):
    mask = [False] * size
    writes = []
    for offset, kind, value in fields:
        width = {'u8': 1, 'u16': 2, 'u32': 4, 'u64': 8, 'f32': 4}[kind]
        mask[offset:offset+width] = [True] * width
        writes.append({'offset': offset, 'type': kind, 'width': width, 'value': value})
    return {'writes': writes, 'valid_bytes': mask, 'unknown_padding': [i for i, v in enumerate(mask) if not v]}


class SceneState:
    def __init__(self):
        self.reset()

    def reset(self):
        self.event = None
        self.target = None
        self.attempted = False
        self.clock = None

    def begin(self, record, target, epoch):
        self.reset()  # Invalid configuration cannot leave a prior target live.
        event = decode(record)
        if not isinstance(target, dict) or not target.get('verified') or not target.get('token') or not target.get('context') or target.get('epoch') != epoch or target.get('namespace') != event['namespace']:
            raise ValueError('explicit source-resolved target/context/epoch required')
        if event['source_event']['tag'] == 'C018':
            scale = target.get('current_native_scale')
            if not isinstance(scale, list) or len(scale) != 3 or not all(math.isfinite(x) for x in scale):
                raise ValueError('current native scale required')
            x, y, z = event['euler']
            sx, sy, sz = [math.sin(v / 2) for v in (x, y, z)]
            cx, cy, cz = [math.cos(v / 2) for v in (x, y, z)]
            result = {'type': 'native_transform_reference', 'position': event['position'], 'scale': scale[:],
                      'quaternion_xyzw': [sx*cy*cz-cx*sy*sz, cx*sy*cz+sx*cy*sz, cx*cy*sz-sx*sy*cz, cx*cy*cz+sx*sy*sz]}
        else:
            s = event['selector']
            result = {'type': 'initial_scheduler_request', 'sheet': 792, 'row': 12+s,
                      'descriptor': descriptor(40, [(0,'u32',12+s),(4,'u32',0),(8,'u64',0),(16,'f32',event['ratio']),
                          (24,'u8',0),(28,'f32',event['denominator']),(32,'u32',event['initial_arg']),(36,'u32',0)])}
            if 'state_byte' in target:
                if type(target['state_byte']) is not int or not 0 <= target['state_byte'] <= 255:
                    raise ValueError('state byte')
                result['state_byte'] = (target['state_byte'] & ~0x20) | 0x10 | (s << 5)
        self.event, self.target = event, copy.deepcopy(target)
        return self.output(result)

    def output(self, result):
        return dict(result, namespace=copy.deepcopy(self.event['namespace']), source_event=copy.deepcopy(self.event['source_event']),
                    decoded=copy.deepcopy(self.event), target=copy.deepcopy(self.target))

    def update(self, clock, target, epoch):
        if self.event is None:
            raise ValueError('not configured')
        if target != self.target or epoch != self.target['epoch']:
            self.reset()
            raise ValueError('stale/remapped target')
        clock = f32(clock)
        if not math.isfinite(clock) or (self.clock is not None and clock < self.clock):
            raise ValueError('nonfinite/rewind; explicit reset required')
        self.clock = clock
        e = self.event
        if e['source_event']['tag'] != 'C196' or self.attempted or clock <= e['threshold_f32']['value']:
            return self.output({'type': 'no_request', 'attempted': self.attempted})
        self.attempted = True  # Emission records attempt, never load success.
        return self.output({'type':'queued_action_request','request_type':32,'row_override':10+e['selector'],
            'row_override_present':1,'explicit_target_argument':None,'generic_parser_bypassed':True,'attempted':True,
            **({'state_byte': (target['state_byte'] & ~0x20) | 0x10 | (e['selector'] << 5)} if 'state_byte' in target else {}),
            'descriptor':descriptor(28,[(0,'u16',0),(4,'f32',scalar(1)),(8,'u16',0),(12,'u64',0),(20,'u32',e['later_arg']),(24,'u32',0)])})
