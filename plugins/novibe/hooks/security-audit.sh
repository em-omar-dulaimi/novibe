#!/bin/sh
# Hold a PR back from ready while its diff crosses a trust boundary that no audit has covered.
input=$(cat)
printf '%s' "$input" | grep -Eq 'gh pr (ready|create)' || exit 0
printf '%s' "$input" | grep -q 'ALLOW_NO_AUDIT=1' && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

installed=
for dir in "$HOME/.claude/skills" .claude/skills "$HOME/.agents/skills" .agents/skills; do
  [ -f "$dir/security-audit/SKILL.md" ] && installed=1
done
[ -n "$installed" ] || exit 0

default=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
base=$(git merge-base "$default" HEAD 2>/dev/null) || exit 0

paths=$(git diff --name-only "$base"..HEAD | grep -Ei "${AUDIT_PATHS:-(auth|login|session|token|crypt|secret|permission|acl|tenant|middleware|route|handler|webhook|cors|cookie|prompt|\.github/workflows/|dockerfile|\.tf$|wrangler\.|package\.json$|requirements.*\.txt$|go\.mod$|cargo\.toml$|pyproject\.toml$)}" || true)
lines=$(git diff "$base"..HEAD | grep -E '^\+[^+]' | grep -Ei "${AUDIT_LINES:-(child_process|subprocess|exec\(|spawn\(|eval\(|innerhtml|dangerouslysetinnerhtml|pickle\.loads|yaml\.load\(|(select|insert|update|delete) .*(from|into|set|where) |verify ?= ?false|rejectunauthorized|access-control-allow|httponly|samesite|jwt|bcrypt|password)}" | head -5 || true)
[ -n "$paths$lines" ] || exit 0

for meta in "${SECURITY_AUDIT_DIR:-$HOME/security-audit-skill}"/*/run-*/run-metadata.json; do
  [ -f "$meta" ] || continue
  for ref in $(grep -Eo '[0-9a-f]{7,40}' "$meta"); do
    git merge-base --is-ancestor "$ref" HEAD 2>/dev/null &&
      git merge-base --is-ancestor "$base" "$ref" 2>/dev/null && exit 0
  done
done

{
  echo "This slice crosses a trust boundary and no security audit covers it:"
  [ -n "$paths" ] && printf '%s\n' "$paths" | head -5 | sed 's/^/  /'
  [ -n "$lines" ] && printf '%s\n' "$lines" | cut -c1-120 | sed 's/^/  /'
  echo "Run security-audit as a full audit, scoped to the diff from $base, quick profile, in its default output directory."
  echo "Not a boundary after all? Ask the driver, then: ALLOW_NO_AUDIT=1 gh pr ..."
} >&2
exit 2
