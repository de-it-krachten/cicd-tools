#!/usr/bin/env python3

import sys
import yaml
import os


def convert_item(item):
    """
    Recursively normalize a YAML structure so that any bare string that is an
    element of a list becomes a {'name': <string>} dict.

    - Dict values are recursed into, but a scalar string value (e.g. version:
      "24.6.1") is left untouched because it is not a list element.
    - List elements that are strings are converted to {'name': <string>}.
    - Existing dict entries in a list keep all their keys (name, version, type...).
    - The operation is idempotent: running it again produces the same result.
    """
    # Dict -> recurse into values
    if isinstance(item, dict):
        return {k: convert_item(v) for k, v in item.items()}

    # List -> turn bare string elements into {'name': str}, recurse into the rest
    if isinstance(item, list):
        out = []
        for x in item:
            if isinstance(x, str):
                out.append({'name': x})
            else:
                out.append(convert_item(x))
        return out

    # Scalar -> unchanged
    return item


def process_yaml_to_stdout(filename):
    if not os.path.exists(filename):
        print(f"Error: File '{filename}' not found.", file=sys.stderr)
        sys.exit(1)

    try:
        with open(filename, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
    except yaml.YAMLError as exc:
        print(f"Error parsing YAML: {exc}", file=sys.stderr)
        sys.exit(1)

    if data is None:
        print("File is empty.", file=sys.stderr)
        sys.exit(1)

    # Process the data structure recursively
    new_data = convert_item(data)

    # Write to STDOUT instead of file
    # default_flow_style=False ensures block style (vertical lists)
    yaml.dump(new_data, sys.stdout, default_flow_style=False,
              sort_keys=False, allow_unicode=True)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python script.py <filename.yaml>", file=sys.stderr)
        sys.exit(1)

    process_yaml_to_stdout(sys.argv[1])
