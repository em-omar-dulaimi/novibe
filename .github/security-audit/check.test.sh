#!/bin/sh
check=$(cd "$(dirname "$0")" && pwd)/check.sh
repo=$(mktemp -d "${TMPDIR:-/tmp}/nvaudit.XXXXXX")
trap 'rm -rf "$repo"' EXIT
cd "$repo" && git init -q && git config user.email t@t && git config user.name t
echo "# app" > README.md && git add -A && git commit -qm base && base=$(git rev-parse HEAD)
failed=0

expect() {
  want=$1 name=$2; shift 2
  env BASE_SHA="${from:-$base}" HEAD_SHA="$(git rev-parse HEAD)" "$@" sh "$check" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$want" ]; then echo "ok   $name"; else echo "FAIL $name (exit $got, want $want)"; failed=1; fi
}

slice() {
  git checkout -q "$base" 2>/dev/null && git checkout -q -B "slice-$1"
  shift
  "$@"
  git add -A && git commit -qm slice
}

docs() { echo "more" >> README.md; }
route() { mkdir -p src && echo 'app.delete("/users/:id", remove)' > src/users.js; }
auth_path() { mkdir -p src && echo 'export const x = 1' > src/auth.js; }
tls_off() { mkdir -p src && echo 'fetch(url, { rejectUnauthorized: false })' > src/client.js; }
removed_check() { mkdir -p src && echo 'if (!jwt.verify(t)) deny()' > src/guard.js && git add -A && git commit -qm guard && : > src/guard.js; }

slice docs docs
expect 0 "a docs-only diff needs no record" PR_BODY=""

slice route route
expect 1 "a new route without a record is refused" PR_BODY="Adds the delete route."
expect 0 "a new route with a record passes" PR_BODY="Adds the delete route.

Security audit: the delete entry point — no confirmed findings."
expect 0 "a record set in bold passes" PR_BODY="**Security audit:** none — the route is behind the admin guard"
expect 0 "a draft waits" DRAFT=true PR_BODY=""
expect 1 "an empty record is refused" PR_BODY="Security audit:"
expect 1 "a record only quoted in prose is refused" PR_BODY="We still need a 'Security audit: ...' line."

slice auth auth_path
expect 1 "a boundary-looking path is refused" PR_BODY=""

slice tls tls_off
expect 1 "turning off TLS verification is refused" PR_BODY=""

slice removed removed_check
from=$(git rev-parse HEAD~1)
expect 1 "removing an auth check that is on the base is refused" PR_BODY=""
from=

slice custom docs
expect 1 "a project's own path pattern is honoured" AUDIT_PATHS="readme" PR_BODY=""

exit $failed
