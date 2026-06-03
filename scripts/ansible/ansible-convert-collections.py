#!/usr/bin/env python3

import sys
import yaml
import os

def convert_item(item):
    """
    Recursively checks if an item is a list of strings and converts it.
    Returns the converted item or the original if no conversion is needed.
    """
    # Case 1: Item is a list of strings -> Convert it
    if isinstance(item, list) and all(isinstance(x, str) for x in item):
        # Check if already converted
        if all(isinstance(x, dict) and 'name' in x for x in item):
            return item 
        return [{'name': x} for x in item]
    
    # Case 2: Item is a dictionary -> Recurse into its values
    if isinstance(item, dict):
        new_dict = {}
        changed = False
        for k, v in item.items():
            new_val = convert_item(v)
            new_dict[k] = new_val
            if new_val is not v:
                changed = True
        return new_dict if changed else item

    # Case 3: Item is a list of mixed types or dicts -> Recurse into list items
    if isinstance(item, list):
        new_list = []
        changed = False
        for x in item:
            new_val = convert_item(x)
            new_list.append(new_val)
            if new_val is not x:
                changed = True
        return new_list if changed else item

    # Case 4: Scalar -> Return as is
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
    yaml.dump(new_data, sys.stdout, default_flow_style=False, sort_keys=False, allow_unicode=True)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python script.py <filename.yaml>", file=sys.stderr)
        sys.exit(1)
    
    process_yaml_to_stdout(sys.argv[1])   
