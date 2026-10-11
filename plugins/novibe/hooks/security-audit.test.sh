#!/bin/sh
# Every way the security-audit hook has been found wrong, kept so none comes back.
hook=$(cd "$(dirname "$0")" && pwd)/security-audit.sh
root=$(mktemp -d "${TMPDIR:-/tmp}/nvhooktest.XXXXXX")
trap 'rm -rf "$root"' EXIT
failed=0

# A slice that adds DELETE /users/:id without the admin check the other admin route has.
slice() {
  dir=$root/$1
  mkdir -p "$dir/repo" && cd "$dir/repo" || exit 1
  git init -q -b main && git config user.email t@t && git config user.name t
  mkdir -p src .claude/skills/security-audit
  echo '---' > .claude/skills/security-audit/SKILL.md
  printf "app.post('/users', requireAdmin, create);\n" > src/server.js
  printf "const store = new Map();\n" > src/users.js
  git add . && git commit -qm main
  git clone -q --bare . ../origin.git && git remote add origin ../origin.git
  git fetch -q origin && git remote set-head origin main
  git switch -q -c slice
}

expect() {
  want=$1 name=$2 command=$3
  jq -n --arg c "$command" '{tool_input:{command:$c}}' |
    CLAUDE_PROJECT_DIR=$dir/repo CLAUDE_CONFIG_DIR=$dir/none HOME=$dir/home sh "$hook" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then echo "ok    $name"; else echo "FAIL  $name (exit $got, want $want)"; failed=1; fi
}

audit() {
  run=$dir/home/security-audit-skill/repo/run-1
  mkdir -p "$run"
  jq -n --arg status "$1" --arg target "$(pwd -P)" --arg commit "$2" --argjson scope "$3" \
    '{run_status: $status, target: $target, source_ref: {commit: $commit}, scope_paths: $scope}' >"$run/run-metadata.json"
  rm -f "$run"/*.md "$run/findings.json"
  [ "$4" = reports ] && for f in findings.json REPORT.md FINDINGS-DETAIL.md NEEDS-VALIDATION.md; do echo x >"$run/$f"; done
}

slice rename
sed -i 's/store/usersById/' src/users.js && git commit -qam rename
expect 0 "a rename in a helper crosses no boundary" 'gh pr ready'
sed -i 's/create/createUser/' src/server.js && git commit -qam rename-handler
expect 2 "any change to a route line is a boundary" 'gh pr ready'

slice route
printf "app.delete('/users/:id', remove);\n" >> src/server.js && git commit -qam route
expect 2 "a new route in an ordinary file is a boundary" 'gh pr ready'
expect 2 "extra spaces" 'gh  pr   ready'
expect 2 "a flag before pr" 'gh -R org/repo pr ready'
expect 2 "gh by path" '/usr/bin/gh pr ready'
expect 2 "a quoted subcommand" 'gh pr "ready"'
expect 2 "a quoted pr" "gh 'pr' ready"
expect 2 "inside if" 'if gh pr ready; then :; fi'
expect 2 "inside braces" '{ gh pr ready; }'
expect 2 "on a second line" "$(printf 'git push\ngh pr ready')"
expect 2 "after &&" 'git push && gh pr ready'
expect 2 "a non-draft create" 'gh pr create --title x'
expect 2 "--draft only in the title" 'gh pr create --title "not --draft mode"'
expect 2 "--draft=false" 'gh pr create --draft=false --title x'
expect 0 "a real --draft" 'gh pr create --draft --title x'
expect 0 "-d" 'gh pr create -d'
expect 0 "--draft=true" 'gh pr create --draft=true'
expect 0 "--draft on a continuation line" "$(printf 'gh pr create --title x \\\n  --draft')"
expect 0 "the override" 'ALLOW_NO_AUDIT=1 gh pr ready'
expect 2 "an override typo" 'ALLOW_NO_AUDIT=10 gh pr ready'
expect 2 "an override in another command" 'echo ALLOW_NO_AUDIT=1; gh pr ready'
expect 2 "an override only in quotes" 'echo "ALLOW_NO_AUDIT=1 gh pr ready"; gh pr ready'
expect 2 "an override only in a heredoc" "$(printf 'gh pr create --body "$(cat <<EOF\nALLOW_NO_AUDIT=1 --draft\nEOF\n)"')"
expect 0 "gh pr ready only in a heredoc" "$(printf "cat <<'EOF'\ngh pr ready\nEOF")"
expect 0 "gh pr ready in a commit message" 'git commit -m "then gh pr ready"'
expect 0 "another gh command" 'gh pr view'
expect 2 "an override on another gh pr call" 'ALLOW_NO_AUDIT=1 gh pr view; gh pr ready'
expect 2 "a wrapper with options" 'env -i gh pr ready'
expect 2 "sudo with an option" 'sudo -u nobody gh pr ready'
expect 2 "an escaped gh" 'g\h pr ready'
expect 2 "<<EOF inside quotes is no heredoc" "$(printf "echo 'example <<EOF'\ngh pr ready")"

head=$(git rev-parse HEAD) base=$(git merge-base origin/main HEAD)
audit in_progress "$head" '[]' reports; expect 2 "an audit still running" 'gh pr ready'
audit complete "$base" '[]' reports; expect 2 "an audit of the commit the slice left from" 'gh pr ready'
audit complete "$head" '["docs"]' reports; expect 2 "an audit scoped to other files" 'gh pr ready'
audit complete "$head" '[]' none; expect 2 "a complete audit without its reports" 'gh pr ready'
audit complete "$head" '[]' reports; expect 0 "a complete audit of the slice" 'gh pr ready'
audit complete "$head" '["src/server.js"]' reports; expect 0 "a complete audit scoped to the flagged file" 'gh pr ready'

slice removed
printf "const tls = { rejectUnauthorized: true };\n" > src/client.js && git add . && git commit -qm tls
git push -q origin slice:main && git fetch -q origin && git reset -q --hard origin/main && git switch -q -C slice
printf "const tls = {};\n" > src/client.js && git commit -qam weaken
expect 2 "removing a security setting is a boundary" 'gh pr ready'

slice uninstalled
rm -rf .claude && git commit -qam uninstall
printf "app.delete('/users/:id', remove);\n" >> src/server.js && git commit -qam route
expect 0 "without the skill installed the hook stays out of the way" 'gh pr ready'

exit $failed
