"""Run every gate test in its own process, several at a time. Python standard library only.

Run: python3 -B gate/run_parallel.py [-j N] [test name ...]
Each test already works in its own temporary repository, so tests share no writable state.
The sequential command stays valid: python3 -B -m unittest discover -s gate -p 'test_*.py'
With QUEUE_TEST_LOG set, transcript lines from different tests may interleave.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest

GATE = Path(__file__).resolve().parent


def names(suite):
    for item in suite:
        if isinstance(item, unittest.TestSuite):
            yield from names(item)
        else:
            yield item.id()


def run(name):
    # The working directory puts gate on the import path, as discover -s gate does.
    p = subprocess.run([sys.executable, '-B', '-m', 'unittest', name], cwd=GATE,
                       capture_output=True, text=True)
    return name, p.returncode, p.stdout + p.stderr


def main(argv=None):
    parser = argparse.ArgumentParser(description='并行运行 gate 下的队列工具测试；每项测试一个进程。')
    parser.add_argument('-j', '--jobs', type=int, default=os.cpu_count() or 1,
                        help='同时运行的测试数，默认本机核心数')
    parser.add_argument('names', nargs='*',
                        help='只跑这些测试，写法如 test_task_queue.QueueIntegration.test_01_init_doctor_and_real_successful_commit；默认全部')
    args = parser.parse_args(argv)
    if args.jobs < 1:
        parser.error('-j 须为正整数')
    loader = unittest.TestLoader()
    sys.path.insert(0, str(GATE))
    selected = args.names or list(names(loader.discover(str(GATE), pattern='test_*.py')))
    if loader.errors:
        print('测试发现失败：\n' + '\n'.join(loader.errors))
        return 1
    if not selected:
        print('没有找到测试。')
        return 1
    started = time.monotonic()
    with ThreadPoolExecutor(args.jobs) as pool:
        results = list(pool.map(run, selected))
    failed = [(name, output) for name, code, output in results if code]
    for name, output in failed:
        print(f'FAIL {name}\n{output}')
    print(f'Ran {len(results)} tests in {time.monotonic() - started:.3f}s with {args.jobs} jobs')
    print(f'FAILED (failures={len(failed)})' if failed else 'OK')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
