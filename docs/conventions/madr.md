# MADR

**An ADR is plain [MADR](https://adr.github.io/madr/), with a number of its own.** The architect
writes ADRs in MADR so anyone can read them the same way, and cites them by number. Left to
itself, an agent drifts from the format, with its own status line or its own section names, and
two branches or one session can take the same next number. Both are facts about the files, so a
linter checks them every time rather than leaving them to review.

`pre-push` lints the committed ADRs with [`madr-lint`](https://github.com/knktkc/madr-lint) when
it is installed: MADR 4's required sections, status and date, the file name, a number used once,
`supersedes` links that agree both ways, and links that resolve. The rules are in
[`.madrlintrc.json`](../../.madrlintrc.json). `ADRS_DIR` if yours live elsewhere, `ALLOW_ADRS=1`
to override.

```
npm i -D madr-lint
npx madr-lint docs/adrs
```

ADRs written before the linter can be snapshotted in a
[baseline](https://knktkc.github.io/madr-lint/guides/adopting-existing-repo/), so only new ones
have to lint.
