#!/usr/bin/env python3
# Reads `pactl list sink-inputs` from stdin, outputs JSON array
# Format: [{"index": N, "app": "...", "volume": 75, "muted": false}, ...]
import sys, json, re

inputs = []
current = {}

for line in sys.stdin:
    line = line.strip()
    m = re.match(r'Sink Input #(\d+)', line)
    if m:
        if current and current.get('app'):
            inputs.append(current)
        current = {'index': int(m.group(1)), 'app': '', 'volume': 100, 'muted': False}
    elif current is not None:
        if line.startswith('Mute:'):
            current['muted'] = 'yes' in line.lower()
        elif line.startswith('Volume:'):
            m2 = re.search(r'(\d+)%', line)
            if m2:
                current['volume'] = int(m2.group(1))
        elif 'application.name' in line:
            m2 = re.search(r'"(.+)"', line)
            if m2:
                current['app'] = m2.group(1)
        elif 'media.name' in line and not current.get('app'):
            m2 = re.search(r'"(.+)"', line)
            if m2:
                current['app'] = m2.group(1)

if current and current.get('app'):
    inputs.append(current)

print(json.dumps(inputs), flush=True)
