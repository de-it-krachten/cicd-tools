#!/bin/bash
ORG="de-it-krachten"

echo "Fetching all repositories in organization: $ORG"

# Get all repos in the org
REPOS=$(gh repo list $ORG --json name --jq ".[].name" --limit 1000 | sort)

echo "$REPOS" | while read repo; do
  echo "=== Checking $repo ==="
  # Get all in-progress or queued runs

  RUNS=$(gh run list --repo "$ORG/$repo" --json name,status,databaseId | jq '.[] | select(.status=="queued") | .databaseId')

  if [ -z "$RUNS" ]; then
    echo "  No running or queued workflows."
  else
    echo "$RUNS" | xargs -I {} gh run cancel --repo "$ORG/$repo" {}
    echo "  Cancelled queued/running workflows."
  fi
done

echo "Bulk cancellation complete."
