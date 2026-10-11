#!/bin/sh
# Hold a PR back from ready while its diff crosses a trust boundary that no finished audit has covered.
input=$(cat)
printf '%s' "$input" | grep -q 'gh' || exit 0
command -v jq >/dev/null || {
  echo "The security-audit guard needs jq to read this command; install jq." >&2
  exit 2
}

# Every simple command in the input, heredoc bodies and quoted text dropped: is one a guarded gh pr call?
guarded=$(printf '%s\n' "$input" | jq -r '.tool_input.command // empty' | awk '
  heredoc != "" { t = $0; if (strip) sub(/^\t+/, "", t); if (t == heredoc) heredoc = ""; next }
  {
    line = cont $0; cont = ""
    if (line ~ /\\$/) { cont = substr(line, 1, length(line) - 1) " "; next }
    if (match(line, /<<-?[ \t]*[\047"]?[A-Za-z_][A-Za-z0-9_]*/)) {
      heredoc = substr(line, RSTART, RLENGTH); strip = heredoc ~ /^<<-/
      sub(/^<<-?[ \t]*[\047"]?/, "", heredoc)
    }
    gsub(/\047[^\047]*\047/, "", line); gsub(/"[^"]*"/, "", line); sub(/[\047"].*/, "", line)
    n = split(line, segs, /;|&&|\|\||\||&|\(|\)|`/)
    for (s = 1; s <= n; s++) {
      m = split(segs[s], tok, /[ \t]+/); i = 1; override = 0
      while (i <= m && (tok[i] == "" || tok[i] == "env" || tok[i] == "command" || tok[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/)) {
        if (tok[i] == "ALLOW_NO_AUDIT=1") override = 1
        i++
      }
      if (tok[i] !~ /(^|\/)gh$/) continue
      for (j = i + 1; j < m && tok[j] != "pr"; j++) ;
      if (tok[j] != "pr" || (tok[j + 1] != "ready" && tok[j + 1] != "create")) continue
      draft = 0
      for (k = j + 2; k <= m; k++) if (tok[k] == "--draft" || tok[k] == "-d" || tok[k] ~ /^--draft=/) draft = 1
      if (tok[j + 1] == "create" && draft) continue
      if (!override) print "guard"
    }
  }')
[ -n "$guarded" ] || exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
top=$(cd "$top" && pwd -P)

# Without Cloudflare's skill installed there is no audit to wait for.
installed=
for dir in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills" "$top/.claude/skills" "$HOME/.agents/skills" \
           "$top/.agents/skills" /etc/claude-code/.claude/skills; do
  [ -f "$dir/security-audit/SKILL.md" ] && installed=1
done
[ -n "$installed" ] || exit 0

default=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) ||
  default=origin/$(git ls-remote --symref origin HEAD 2>/dev/null | sed -n 's|^ref: refs/heads/\(.*\)[[:space:]]HEAD$|\1|p')
base=$(git merge-base "$default" HEAD 2>/dev/null) || {
  echo "Cannot find where this slice branched from the default branch, so cannot tell whether it needs a security audit." >&2
  echo "Run: git remote set-head origin --auto && git fetch origin" >&2
  exit 2
}

path_pattern="${AUDIT_PATHS:-(auth|login|session|token|crypt|secret|permission|acl|tenant|middleware|route|handler|webhook|cors|cookie|prompt|\.github/workflows/|dockerfile|\.tf$|wrangler\.|package\.json$|requirements.*\.txt$|go\.mod$|cargo\.toml$|pyproject\.toml$)}"
line_pattern="${AUDIT_LINES:-((app|router|server|fastify)\.(get|post|put|patch|delete|all|use|route)\(|@(app|router|bp|blueprint)\.(route|get|post|put|patch|delete)\(|@(get|post|put|patch|delete|requestmapping)(mapping)?\(|child_process|subprocess|exec\(|spawn\(|eval\(|innerhtml|dangerouslysetinnerhtml|pickle\.loads|yaml\.load\(|(select|insert|update|delete) .*(from|into|set|where) |verify ?= ?false|rejectunauthorized|access-control-allow|httponly|samesite|jwt|bcrypt|password)}"
files=$(git diff --name-only "$base"..HEAD | while IFS= read -r file; do
  if printf '%s\n' "$file" | grep -Eiq "$path_pattern" ||
     git diff "$base"..HEAD -- "$file" | grep -E '^[+-]' | grep -Ev '^(\+\+\+|---)( |$)' | grep -Eiq "$line_pattern"; then
    printf '%s\n' "$file"
  fi
done)
[ -n "$files" ] || exit 0

# A run counts only if it finished with its reports, audited this repository at a commit on the slice, and covers every flagged file.
covers() {
  meta=$1
  [ "$(jq -r '.run_status // empty' "$meta")" = complete ] || return 1
  for report in findings.json REPORT.md FINDINGS-DETAIL.md NEEDS-VALIDATION.md; do
    [ -s "$(dirname "$meta")/$report" ] || return 1
  done
  target=$(jq -r '.target // empty' "$meta")
  [ -n "$target" ] && [ "$(cd "$target" 2>/dev/null && pwd -P)" = "$top" ] || return 1
  on_slice=
  for ref in $(jq -r '.source_ref | if type == "object" then .commit // empty else . end | tostring' "$meta" | grep -Eo '[0-9a-f]{7,40}'); do
    ref=$(git rev-parse -q --verify "$ref^{commit}" 2>/dev/null) || continue
    [ "$ref" != "$base" ] &&
      git merge-base --is-ancestor "$ref" HEAD 2>/dev/null &&
      git merge-base --is-ancestor "$base" "$ref" 2>/dev/null && on_slice=1
  done
  [ -n "$on_slice" ] || return 1
  scopes=$(jq -r '(.scope_paths // [])[] | tostring' "$meta" | sed -e "s|^$top/||" -e 's|^\./||' -e 's|/$||')
  printf '%s\n' "$scopes" | grep -Eqx '|\.' && return 0
  printf '%s\n' "$files" | while IFS= read -r file; do
    printf '%s\n' "$scopes" | while IFS= read -r scope; do
      case $file in "$scope" | "$scope"/*) echo hit; break ;; esac
    done | grep -q hit || { echo miss; break; }
  done | grep -q miss && return 1
  return 0
}
for meta in "${SECURITY_AUDIT_DIR:-$HOME/security-audit-skill}"/*/run-*/run-metadata.json; do
  [ -f "$meta" ] && covers "$meta" && exit 0
done

{
  echo "This slice crosses a trust boundary and no finished security audit of this repository covers it:"
  printf '%s\n' "$files" | head -10 | sed 's/^/  /'
  echo "Run security-audit as a full audit of $top, scoped to these files, at HEAD, quick profile, in its default output directory."
  echo "Not a boundary after all? Ask the driver, then: ALLOW_NO_AUDIT=1 gh pr ..."
} >&2
exit 2
