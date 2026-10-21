#!/usr/bin/env python3
"""Measure owned preview processes. Run only during the final desktop test batch."""
import argparse
import json
import os
import platform
import signal
import statistics
import subprocess
import time
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('app', type=Path)
p.add_argument('fixture', type=Path)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--allow-desktop', action='store_true', help='Explicitly allow app launches on this desktop')
a = p.parse_args()
if not a.allow_desktop and not (os.environ.get('GITHUB_ACTIONS') == 'true' and os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted'):
    p.error('App launches are remote by default. Local desktop execution requires --allow-desktop.')
app = a.app.resolve()
exe = app / 'Contents/MacOS/OpenMTP Native'
script_dir = Path(__file__).resolve().parent
probe = script_dir.parent / 'build/window-probe'
subprocess.run(['swiftc', '-O', str(script_dir / 'WindowProbe.swift'), '-o', str(probe)], check=True)

class OwnedApplication:
    def __init__(self, pid):
        self.pid = pid

    def poll(self):
        try:
            os.kill(self.pid, 0)
            return None
        except ProcessLookupError:
            return 0

    def terminate(self):
        if self.poll() is None:
            os.kill(self.pid, signal.SIGTERM)

    def kill(self):
        if self.poll() is None:
            os.kill(self.pid, signal.SIGKILL)

    def wait(self, timeout=5):
        deadline = time.monotonic() + timeout
        while self.poll() is None:
            if time.monotonic() >= deadline:
                raise subprocess.TimeoutExpired(['owned-native-app', str(self.pid)], timeout)
            time.sleep(0.01)

def launch():
    a.output.parent.mkdir(parents=True, exist_ok=True)
    report_file = a.output.with_suffix('.launch.json')
    report_file.unlink(missing_ok=True)
    process = None
    try:
        with a.output.with_suffix('.launch.log').open('a') as log:
            subprocess.run([str(probe), '--launch', str(app), str(report_file), '--ui-testing', '--directory', str(a.fixture.resolve())], stdout=subprocess.DEVNULL, stderr=log, check=True, timeout=25)
        report = json.loads(report_file.read_text())
        process = OwnedApplication(report['pid'])
        if report['first_window_seconds'] is None:
            raise RuntimeError(f"Preview did not present its first window: {report}")
    except BaseException:
        if process is None and report_file.exists():
            process = OwnedApplication(json.loads(report_file.read_text())['pid'])
        if process is not None:
            try:
                subprocess.run(['sample', str(process.pid), '1', '-file', str(a.output.with_suffix('.sample.txt'))], capture_output=True, timeout=5)
            except subprocess.TimeoutExpired:
                pass
            stop(process)
        raise
    return process, report['first_window_seconds']

def stop(process):
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()

def cpu_seconds(value):
    days = 0
    if '-' in value:
        prefix, value = value.split('-', 1)
        days = int(prefix)
    parts = list(map(float, value.split(':')))
    result = days * 86400
    for power, part in enumerate(reversed(parts)):
        result += part * 60**power
    return result

def snapshot(root):
    lines = subprocess.check_output(['ps', '-axo', 'pid=,ppid=,rss=,time='], text=True).splitlines()
    rows = [line.split() for line in lines]
    owned = {root}
    changed = True
    while changed:
        additions = {int(row[0]) for row in rows if int(row[1]) in owned} - owned
        changed = bool(additions)
        owned |= additions
    selected = [row for row in rows if int(row[0]) in owned]
    return sum(int(row[2]) for row in selected) / 1024, sum(cpu_seconds(row[3]) for row in selected), sorted(owned)

warm = []
# Prime system caches without including this launch in the ten warm samples.
process, _ = launch()
stop(process)
for _ in range(10):
    process, elapsed = launch()
    warm.append(elapsed)
    stop(process)
process, _ = launch()
try:
    _, cpu_start, _ = snapshot(process.pid)
    sample_start = time.perf_counter()
    time.sleep(30)
    if process.poll() is not None:
        raise RuntimeError("Preview exited during the idle measurement")
    rss, cpu_end, pids = snapshot(process.pid)
    sample_elapsed = time.perf_counter() - sample_start
finally:
    stop(process)
median = statistics.median(warm)
cpu = (cpu_end - cpu_start) / sample_elapsed * 100
result = {
    'platform': platform.platform(), 'app': str(app), 'fixture': str(a.fixture.resolve()),
    'fixture_entries': len(list(a.fixture.iterdir())), 'warm_window_seconds': warm,
    'median_warm_window_seconds': median, 'rss_mib_at_30_seconds': rss,
    'idle_cpu_one_core_percent': cpu, 'cpu_sample_seconds': sample_elapsed, 'owned_pids': pids,
    'passes': {'warm_window_at_most_0_75_seconds': median <= 0.75, 'rss_at_most_150_mib': rss <= 150, 'cpu_at_most_1_percent': cpu <= 1},
    'method': 'Monotonic timer immediately before NSWorkspace launch request to first owned on-screen window via CoreGraphics. Observer process startup excluded. New owned app instance each launch. Summed ps RSS and process CPU time. One cache-prime launch excluded.',
}
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
