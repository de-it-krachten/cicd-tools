#!/usr/bin/env python3

import re
import sys
import argparse
import subprocess
import urllib.request
import urllib.error
import urllib.parse
import json
import yaml
from packaging import version as pkg_version
from packaging.specifiers import SpecifierSet

GALAXY_BASE_URL = "https://galaxy.ansible.com/api/v3/plugin/ansible/content/published/collections/index"

def find_version(ansible_version, namespace, name):
    """Fetches all versions via pagination and finds the latest compatible one."""
    parsed_ansible = pkg_version.parse(ansible_version)
    compatible = []

    # Initial URL
    url = f"{GALAXY_BASE_URL}/{namespace}/{name}/versions/?limit=100"

    while url:
        try:
            with urllib.request.urlopen(url) as response:
                data = json.loads(response.read())
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            print(f"ERROR: API request failed for {namespace}.{name} (HTTP {e.code})", file=sys.stderr)
            return None
        except Exception as e:
            print(f"ERROR: Network error for {namespace}.{name}: {e}", file=sys.stderr)
            return None

        # Process current page
        for item in data.get('data', []):
            req = (item.get('requires_ansible') or '*').strip().strip('"').strip("'")
            ver_str = item['version']

            try:
                # 1. Check Ansible compatibility
                if req != '*' and parsed_ansible not in SpecifierSet(req, prereleases=True):
                    continue

                # 2. Validate Version String (Skip non-SemVer tags like '0.3.0-experimental...')
                try:
                    pkg_version.parse(ver_str)
                    compatible.append(ver_str)
                except pkg_version.InvalidVersion:
                    # Skip this specific version string but continue processing others
                    print(f"DEBUG: Skipping invalid SemVer '{ver_str}' for {namespace}.{name}", file=sys.stderr)
                    continue

            except Exception:
                continue

        # Handle Pagination
        links = data.get('links', {})
        next_link = links.get('next')

        if next_link:
            # The API returns relative paths. urljoin resolves them against the base URL.
            url = urllib.parse.urljoin(GALAXY_BASE_URL + "/", next_link)
        else:
            url = None

    return max(compatible, key=pkg_version.parse) if compatible else None

def detect_ansible_version():
    result = subprocess.run(['ansible', '--version'], capture_output=True, text=True)
    match = re.search(r'ansible\s+(?:\[core\s+)?([\d.]+)', result.stdout)
    if not match:
        print("ERROR: could not detect ansible version", file=sys.stderr)
        sys.exit(1)
    return match.group(1)

def is_git_source(collection):
    """Determines if a collection entry is sourced from Git/URL rather than Galaxy."""
    # Explicit type check
    if collection.get('type') in ['git', 'url', 'file', 'dir', 'subdirs']:
        return True

    # Implicit check: name looks like a URL
    name = collection.get('name', '')
    if name.startswith(('http://', 'https://', 'git@', 'git+', 'file://', '/')):
        return True

    return False

def main():
    parser = argparse.ArgumentParser(description='Pin Ansible collection versions for a given Ansible version.')
    parser.add_argument('requirements', help='Path to requirements YAML file')
    parser.add_argument('ansible_version', nargs='?', help='Ansible version to target (default: detected from ansible --version)')
    parser.add_argument('--overwrite', action='store_true', help='Overwrite already-pinned versions')
    parser.add_argument('--stdout', action='store_true', help='Write output to stdout instead of back to the file')
    args = parser.parse_args()

    ansible_version = args.ansible_version or detect_ansible_version()
    print(f"Target Ansible Version: {ansible_version}", file=sys.stderr)

    try:
        with open(args.requirements) as f:
            data = yaml.safe_load(f)
    except Exception as e:
        print(f"ERROR: Failed to read {args.requirements}: {e}", file=sys.stderr)
        sys.exit(1)

    collections = data if isinstance(data, list) else data.get('collections', [])

    for collection in collections:
        # 1. Skip Git/Local sources entirely (do not modify version, do not lookup)
        if is_git_source(collection):
            src_name = collection.get('name', 'unknown')
            src_ver = collection.get('version', 'unpinned')
            print(f"SKIP: {src_name} (Git/Local source, preserving version '{src_ver}')", file=sys.stderr)
            continue

        # 2. Handle existing pins for Galaxy collections only
        if collection.get('version'):
            # Only strip 'v' for Galaxy collections where version is semver
            clean_ver = collection['version'].lstrip('v')
            collection['version'] = clean_ver
            if not args.overwrite:
                continue

        # 3. Validate namespace.name format
        src_name = collection.get('name', '')
        if '.' not in src_name:
            print(f"SKIP: {src_name} (Invalid namespace.name format)", file=sys.stderr)
            continue

        # 4. Lookup version
        namespace, name = src_name.split('.', 1)
        version = find_version(ansible_version, namespace, name)

        if version:
            # Galaxy API returns semver, usually without 'v', but ensure consistency
            collection['version'] = version.lstrip('v')
            print(f"PINNED: {src_name} -> {version}", file=sys.stderr)
        else:
            print(f"WARNING: No compatible version found for {src_name}", file=sys.stderr)

    # 5. Output
    output_data = {'collections': collections} if not isinstance(data, list) else collections

    if args.stdout:
        sys.stdout.write('---\n')
        yaml.dump(output_data, sys.stdout, default_flow_style=False, allow_unicode=True, sort_keys=False)
    else:
        with open(args.requirements, 'w') as f:
            f.write('---\n')
            yaml.dump(output_data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
        print(f"Updated {args.requirements}", file=sys.stderr)

if __name__ == '__main__':
    main()
