#!/bin/sh
[ "${DRAFT:-false}" = "true" ] && { echo "Draft: no audit record needed yet."; exit 0; }
base=${BASE_SHA:?} head=${HEAD_SHA:?}

path_pattern="${AUDIT_PATHS:-(auth|login|session|token|crypt|secret|permission|acl|tenant|middleware|route|handler|webhook|cors|cookie|prompt|\.github/workflows/|dockerfile|\.tf$|wrangler\.|package\.json$|requirements.*\.txt$|go\.mod$|cargo\.toml$|pyproject\.toml$)}"
line_pattern="${AUDIT_LINES:-((app|router|server|fastify)\.(get|post|put|patch|delete|all|use|route)\(|@(app|router|bp|blueprint)\.(route|get|post|put|patch|delete)\(|@(get|post|put|patch|delete|requestmapping)(mapping)?\(|child_process|subprocess|exec\(|spawn\(|eval\(|innerhtml|dangerouslysetinnerhtml|pickle\.loads|yaml\.load\(|(select|insert|update|delete) .*(from|into|set|where) |verify ?= ?false|rejectunauthorized|access-control-allow|httponly|samesite|jwt|bcrypt|password)}"

files=$(git diff --name-only "$base"..."$head" | while IFS= read -r file; do
  if printf '%s\n' "$file" | grep -Eiq "$path_pattern" ||
     git diff "$base"..."$head" -- "$file" | grep -E '^[+-]' | grep -Ev '^(\+\+\+|---)( |$)' | grep -Eiq "$line_pattern"; then
    printf '%s\n' "$file"
  fi
done)
[ -n "$files" ] || { echo "The diff crosses no trust boundary: no audit record needed."; exit 0; }

if printf '%s\n' "${PR_BODY:-}" | tr -d '\r' | grep -Eiq '^[[:space:]>*_-]*security audit:[*_]*[[:space:]]*[^[:space:]]'; then
  echo "The PR records its security audit:"
  printf '%s\n' "${PR_BODY:-}" | tr -d '\r' | grep -Ei 'security audit:' | head -3
  exit 0
fi

echo "This PR crosses a trust boundary, and its description records no security audit:"
printf '%s\n' "$files" | head -10 | sed 's/^/  /'
echo "Add a line to the PR description, then this check runs again:"
echo "  Security audit: <the boundary audited, and what the audit found>"
echo "  Security audit: none — <why this slice crosses no boundary after all>"
exit 1
