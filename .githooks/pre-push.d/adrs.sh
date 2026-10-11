#!/bin/sh
[ "${ALLOW_ADRS:-}" = "1" ] && exit 0
dir=${ADRS_DIR:-docs/adrs}
git cat-file -e "HEAD:$dir" 2>/dev/null || exit 0

# Two ADRs with the same number, as committed: 0026-a.md and 26-b.md count as the same.
dupes=$(git ls-tree --name-only HEAD "$dir/" | sed 's#.*/##' | grep -E '^[0-9]+' |
  awk '{ n = $0; sub(/[^0-9].*/, "", n); n += 0; names[n] = names[n] "\n  " $0; count[n]++ }
       END { for (n in count) if (count[n] > 1) printf "%s", names[n] }')
if [ -n "$dupes" ]; then
  echo "pre-push: these ADRs share a number:$dupes" >&2
  echo "pre-push: renumber the newer one to the next free number, or override: ALLOW_ADRS=1 git push" >&2
  exit 1
fi
exit 0
