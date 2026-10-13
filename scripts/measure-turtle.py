#!/usr/bin/env python3
"""Sample the production turtle sidebar with synthetic accounts; do not capture frames while measuring."""
import json
import os
from pathlib import Path
import re
import statistics
import subprocess

root = Path(__file__).resolve().parent.parent
out = root / 'build/turtle-review/performance'
out.mkdir(parents=True, exist_ok=True)
probe = root / '.build/performance/probe'
source = root / 'scripts/performance-probe.swift'
probe.parent.mkdir(parents=True, exist_ok=True)
if not probe.exists() or source.stat().st_mtime > probe.stat().st_mtime:
    subprocess.run(['xcrun', 'swiftc', '-O', str(source), '-o', str(probe)], check=True)
process = sampler = None
try:
    with (out / 'scenario.log').open('w') as log, (out / 'resources.jsonl').open('w') as samples:
        process = subprocess.Popen([str(root / 'build/AetherNotchQuota.app/Contents/MacOS/NotchQuota'),
                                    '--sidebar-test', '--turtle-test', '--turtle-benchmark'], stdout=log, stderr=subprocess.STDOUT,
                                   env={k: os.environ[k] for k in ('HOME', 'PATH', 'TMPDIR') if k in os.environ})
        sampler = subprocess.Popen([str(probe), '90', '1', str(process.pid)], stdout=samples)
        code = process.wait(timeout=95)
        sampler.wait(timeout=5)
    log = (out / 'scenario.log').read_text()
    assert code == 0 and 'TURTLE BENCH COMPLETE: PASS' in log, log
    phases = {name: float(stamp) for name, stamp in re.findall(r'TURTLE BENCH (walking|stationary|swimming|idle) ([\d.]+)', log)}
    samples = [json.loads(line) for line in (out / 'resources.jsonl').read_text().splitlines()]
    result = {}
    for phase, start, end in [('walking', phases['walking'], phases['stationary']),
                              ('stationary', phases['stationary'], phases['swimming']),
                              ('swimming', phases['swimming'], phases['idle']),
                              ('idle', phases['idle'] + 1, phases['idle'] + 9)]:
        values = [s for s in samples if s.get('event') == 'sample'
                  and s['timestamp'] - s['interval_s'] >= start and s['timestamp'] <= end]
        assert values, phase
        result[phase] = dict(samples=len(values),
                             meanCPUPercentOneCore=statistics.mean(s['cpu_percent_one_core'] for s in values),
                             maxCPUPercentOneCore=max(s['cpu_percent_one_core'] for s in values),
                             peakFootprintMiB=max(s['footprint_mib'] for s in values),
                             meanIdleWakeupsPerSecond=statistics.mean(s['idle_wakeups_per_s'] for s in values))
    result['decodedTextureLimitBytes'] = 8 * 1024 * 1024 + 256 * 256 * 4
    result['limits'] = ('Short local measurement of production turtle sidebar with synthetic accounts. '
                        'Application CPU only, excluding WindowServer/GPU and frame pacing; '
                        'not an energy or whole-product guarantee.')
    (out / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
finally:
    for child in (process, sampler):
        if child is not None and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
