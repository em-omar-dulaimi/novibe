# ADRs

**Every ADR has a number of its own.** The architect gives a new ADR the next number in
`docs/adrs/`, but two branches can each take the same next number, and so can an agent that
writes two in one session. An ADR is cited by its number, so two with one number make every
citation of it ambiguous.

`pre-push` refuses a push when two committed ADRs share a number: the leading digits of their
file names, so `0026-a.md` and `26-b.md` count as the same. `ADRS_DIR` if yours live elsewhere,
`ALLOW_ADRS=1` to override.
