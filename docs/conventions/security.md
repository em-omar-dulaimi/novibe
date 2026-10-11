# Security

**A credential is never committed in the first place.** `.gitignore` is not enough on its own:
it has no effect once a file is tracked, and a branch cut before the rule existed has nothing.

## What `pre-commit` refuses

- **A staged file whose *path* looks like a credential** — `.env`, [`.dev.vars`](https://developers.cloudflare.com/workers/configuration/secrets/) (Cloudflare
  Workers), `secrets.yaml`, `*.secret`, each with their environment suffixes, and with
  `.example`, `.sample` and `.template` allowed. Checking the path means it does not depend on
  recognising what is inside. This one fails closed **and takes no override** — an escape hatch
  here is the only failure it exists to prevent.
- **A secret found by [`gitleaks`](https://github.com/gitleaks/gitleaks)** in the staged
  changes, when it is installed. This one fails
  open, so not having the tool does not block anybody.

If something is already tracked, `git rm --cached <path>` — the file stays on disk.

## On GitHub

Turn on what finds known problems the same way every time — free on public repositories; private
ones need GitHub's security products:

- **Code scanning** (CodeQL, default setup) — known vulnerability patterns, with Copilot Autofix
  proposing the fix.
- **Secret scanning with push protection** — a token or key refused at the push.
- **Dependency review** — a new dependency with a known vulnerability.

What a scanner cannot see — a new entry point without an authorization check, input used before
the boundary validates it, one tenant's data reachable by another — is for review:
[`.github/skills/security-review`](../../.github/skills/security-review/).

## Before the PR goes ready

The `developer` step runs `security-audit` on the slice's diff, but
only when that diff crosses a trust boundary: a new entry point, authentication, untrusted input
reaching an interpreter, per-tenant data, secrets, dependencies or deployment config. The audit
is thorough and heavy, so a slice that crosses no boundary skips it, and the PR says why.

The plugin's `PreToolUse` hook keeps that from being skipped by mistake. It holds back
`gh pr ready` and a non-draft `gh pr create` when the slice's diff touches boundary-looking
paths or lines and no run in `~/security-audit-skill/` covers it. A run covers it when it
completed, audited this repository at a commit on the slice, and its scope includes every flagged
file. The hook reads the command and the run's metadata with `jq`; a `--draft` or
`ALLOW_NO_AUDIT=1` inside quoted text does not count. Override after asking the
driver with `ALLOW_NO_AUDIT=1 gh pr …`. To match your codebase, set `AUDIT_PATHS` and
`AUDIT_LINES` (extended regexes), or `SECURITY_AUDIT_DIR`.

[`plugins/novibe/evals/`](../../plugins/novibe/evals/) checks both. The `audit-decision` cases
check that the developer step audits a slice adding an unguarded route and skips one that only
renames. The `hook` cases need Bash, so they run only where the eval sandbox works:

```bash
cd plugins/novibe
claude plugin eval . --scaffold --allow-tools Write --tag audit-decision
claude plugin eval . --scaffold --allow-tools Bash --tag hook
```

The plugin ships `security-audit`, unmodified, from Cloudflare's
[security-audit-skill](https://github.com/cloudflare/security-audit-skill) at
[`c1c8a8c`](https://github.com/cloudflare/security-audit-skill/tree/c1c8a8c1471069fb0e188eeaff69b8e8db6564a8),
under its MIT licence. To update it, copy a newer `skills/security-audit/` over
[`plugins/novibe/skills/security-audit/`](../../plugins/novibe/skills/security-audit/) and move
this pin.

## If you add a gitleaks allowlist

Anchor the patterns **and** set `regexTarget = "secret"`:

```toml
[[rules]]
id = "generic-api-key"
[rules.allowlist]
regexTarget = "secret"
regexes = ['''^the-exact-value-that-is-not-a-secret$''']
```

Anchoring alone tests the regex against the rule's whole match — key name and separator
included — so `^value$` matches nothing and the allowlist allows nothing. That looks like it
worked, right until the findings it was meant to permit all come back.

Allow the value, not the rule and not the file. A muted rule stays muted over code nobody has
written yet.

The full schema is in [gitleaks' configuration docs](https://github.com/gitleaks/gitleaks#configuration).
