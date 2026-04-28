#!/usr/bin/env python3

import re
import sys
import argparse
import subprocess
import urllib.request
import json
import yaml
from packaging import version as pkg_version
from packaging.specifiers import SpecifierSet

GALAXY_URL = "https://galaxy.ansible.com/api/v3/plugin/ansible/content/published/collections/index/{namespace}/{name}/versions/?limit=100"


def find_version(ansible_version, namespace, name):
    url = GALAXY_URL.format(namespace=namespace, name=name)
    with urllib.request.urlopen(url) as response:
        data = json.loads(response.read())['data']

    parsed_ansible = pkg_version.parse(ansible_version)
    compatible = []

    for item in data:
        req = (item.get('requires_ansible') or '*').strip().strip('"').strip("'")
        try:
            if req == '*' or parsed_ansible in SpecifierSet(req, prereleases=True):
                compatible.append(item['version'])
        except Exception:
            continue

    return max(compatible, key=pkg_version.parse) if compatible else None


def detect_ansible_version():
    result = subprocess.run(['ansible', '--version'], capture_output=True, text=True)
    match = re.search(r'ansible\s+(?:\[core\s+)?([\d.]+)', result.stdout)
    if not match:
        print("ERROR: could not detect ansible version", file=sys.stderr)
        sys.exit(1)
    return match.group(1)


def main():
    parser = argparse.ArgumentParser(description='Pin Ansible collection versions for a given Ansible version.')
    parser.add_argument('requirements', help='Path to requirements YAML file')
    parser.add_argument('ansible_version', nargs='?', help='Ansible version to target (default: detected from ansible --version)')
    parser.add_argument('--overwrite', action='store_true', help='Overwrite already-pinned versions')
    parser.add_argument('--stdout', action='store_true', help='Write output to stdout instead of back to the file')
    args = parser.parse_args()
    ansible_version = args.ansible_version or detect_ansible_version()

    with open(args.requirements) as f:
        data = yaml.safe_load(f)

    collections = data if isinstance(data, list) else data.get('collections', [])
    for collection in collections:
        if collection.get('version'):
            collection['version'] = collection['version'].lstrip('v')
            if not args.overwrite:
                continue
        namespace, name = collection['name'].split('.', 1)
        version = find_version(ansible_version, namespace, name)
        if version:
            collection['version'] = version.lstrip('v')
        else:
            print(f"WARNING: no compatible version found for {collection['name']}", file=sys.stderr)

    if args.stdout:
        sys.stdout.write('---\n')
        yaml.dump(data, sys.stdout, default_flow_style=False, allow_unicode=True, sort_keys=False)
    else:
        with open(args.requirements, 'w') as f:
            f.write('---\n')
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)


if __name__ == '__main__':
    main()
