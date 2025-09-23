#!/bin/env python3

import sys
import yaml
from pathlib import Path
from collections.abc import Mapping

def deep_merge(a, b):
    """Recursively merge dict b into dict a."""
    for key in b:
        if key in a and isinstance(a[key], dict) and isinstance(b[key], dict):
            deep_merge(a[key], b[key])
        else:
            a[key] = b[key]
    return a

def load_yaml(path):
    with open(path, 'r') as f:
        return yaml.safe_load(f)

def main(file1, file2):
    data1 = load_yaml(file1) or {}
    data2 = load_yaml(file2) or {}

    if not isinstance(data1, Mapping) or not isinstance(data2, Mapping):
        print("Top-level YAML elements must be dictionaries", file=sys.stderr)
        sys.exit(1)

    merged = deep_merge(data1, data2)
    yaml.dump(merged, sys.stdout, sort_keys=False)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python merge_yaml.py file1.yaml file2.yaml", file=sys.stderr)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])

