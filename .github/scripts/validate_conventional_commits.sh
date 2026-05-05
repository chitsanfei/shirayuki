#!/usr/bin/env bash

set -euo pipefail

range="${1:-}"

if [[ -z "$range" ]]; then
  echo "Usage: $0 <git-range>"
  exit 2
fi

pattern='^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([[:alnum:]./_-]+\))?(!)?: .+'

mapfile -t commits < <(git log --no-merges --format='%H%x09%s' "$range")

if [[ "${#commits[@]}" -eq 0 ]]; then
  echo "No non-merge commits to validate in range: $range"
  exit 0
fi

failures=0

for entry in "${commits[@]}"; do
  sha="${entry%%$'\t'*}"
  subject="${entry#*$'\t'}"

  if [[ "$subject" =~ $pattern ]]; then
    echo "PASS ${sha:0:7} $subject"
  else
    echo "::error title=Invalid commit message::${sha:0:7} $subject"
    failures=1
  fi
done

if [[ "$failures" -ne 0 ]]; then
  echo "Expected Conventional Commits format: type(scope)!: description"
  echo "Allowed types: build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test"
  exit 1
fi
