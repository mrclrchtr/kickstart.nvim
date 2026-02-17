#!/usr/bin/env bash
set -euo pipefail

repo="nvim-lua/kickstart.nvim"

usage() {
  cat <<'USAGE'
Usage: scripts/merge-pr.sh <pr-number|pr-url>

Fetches a PR from https://github.com/nvim-lua/kickstart.nvim and merges it into
your currently checked-out branch, creating a local merge commit.

Examples:
  scripts/merge-pr.sh 1862
  scripts/merge-pr.sh https://github.com/nvim-lua/kickstart.nvim/pull/1862
USAGE
}

pr="${1:-}"
if [[ -z "$pr" || "$pr" == "-h" || "$pr" == "--help" ]]; then
  usage
  exit 2
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Not inside a git repository." >&2
  exit 1
}

target_branch="$(git symbolic-ref -q --short HEAD 2>/dev/null || true)"
if [[ -z "$target_branch" ]]; then
  echo "Detached HEAD. Checkout a branch before merging." >&2
  exit 1
fi

# Allow untracked files, but refuse staged/unstaged changes.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree has changes. Commit/stash before merging." >&2
  exit 1
fi

if [[ "$pr" =~ ^https://github.com/([^/]+/[^/]+)/pull/([0-9]+) ]]; then
  if [[ "${BASH_REMATCH[1]}" != "$repo" ]]; then
    echo "This helper only supports PRs from https://github.com/${repo}." >&2
    exit 2
  fi
  pr="${BASH_REMATCH[2]}"
fi

if ! [[ "$pr" =~ ^[0-9]+$ ]]; then
  echo "PR must be a number or a GitHub PR URL." >&2
  exit 2
fi

pr_branch="pr-${pr}"

git branch -D "$pr_branch" >/dev/null 2>&1 || true

fetch_pr_with_gh() {
  command -v gh >/dev/null 2>&1 || return 1
  gh pr checkout "$pr" --repo "$repo" --branch "$pr_branch" --force >/dev/null
}

fetch_pr_with_git() {
  git fetch "git@github.com:${repo}.git" "pull/${pr}/head:${pr_branch}" \
    || git fetch "https://github.com/${repo}.git" "pull/${pr}/head:${pr_branch}"
}

fetch_pr_with_gh || fetch_pr_with_git

git checkout "$target_branch" >/dev/null

git merge --no-ff -m "Merge PR #${pr}" "$pr_branch"

git branch -D "$pr_branch" >/dev/null 2>&1 || true

echo "Merged PR #${pr} into '${target_branch}' (local only)."
