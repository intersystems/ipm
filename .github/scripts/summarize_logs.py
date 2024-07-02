#!/usr/bin/env python3
# Summarize logs in a directory
# Usage: summarize_logs.py <log_dir>


import sys
import re
import glob


if len(sys.argv) != 2:
    print(f"Usage: {sys.argv[0]} <log_dir>", file=sys.stderr)
    sys.exit(1)

p_pat = re.compile(r"Test for package (\S+) passed")
f_pat = re.compile(r"Test for package (\S+) failed")

passed, failed = set(), set()

for fn in glob.glob(f"{sys.argv[1]}/*.txt"):
    with open(fn) as f:
        for line in f.readlines():
            m = p_pat.search(line)
            if m:
                passed.add(m.group(1))
            m = f_pat.search(line)
            if m:
                failed.add(m.group(1))

passed.remove("$package")
failed.remove("$package")

print(f"A total of {len(passed)} packages passed:", sorted(passed))
print(f"A total of {len(failed)} packages failed:", sorted(failed))
