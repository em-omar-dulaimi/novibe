#!/usr/bin/env bash
# A support knowledge base whose slice makes an article name the procedure that resolves it — a product rule that belongs in the spec, not in an ADR.
set -euo pipefail
git init -q -b main
git config user.email eval@example.com
git config user.name eval
mkdir -p docs/architecture/models docs/architecture/views docs/adrs features/support
cat > docs/architecture/likec4.config.mjs <<'MJS'
import { defineConfig } from 'likec4/config'
export default defineConfig({ name: 'helpdesk', metadata: { description: 'What the support team knows about the problems it sees, and how to fix them.' } })
MJS
cat > docs/architecture/models/base-model.c4 <<'C4'
specification {
  element person
  element system
  element application
  element concept
}
model {
  engineer = person 'Support engineer' 'Looks up a problem and fixes it.'
  helpdesk = system 'Helpdesk' {
    knowledge = application 'Knowledge' 'Holds articles and procedures, and refuses what is incomplete.' {
      article = concept 'Article' 'A known problem: how it shows, why it happens, and what to do about it, as text.'
      procedure = concept 'Procedure' 'The steps that fix a problem, with the tools each step uses.'
    }
  }
  engineer -> helpdesk.knowledge 'looks up articles and follows procedures'
}
C4
cat > docs/architecture/views/views.c4 <<'C4'
views {
  view context {
    title 'Context'
    include *
  }
  view knowledge of helpdesk.knowledge {
    title 'Knowledge'
    include *
  }
}
C4
cat > docs/adrs/0001-knowledge-lives-in-one-graph.md <<'MD'
---
status: accepted
date: 2026-09-01
---

# Knowledge lives in one graph

## Context and Problem Statement

Articles, procedures and the tools they use refer to each other, and every feature reads them together.

## Decision Outcome

One graph database holds all knowledge; every feature reads and writes it through the Knowledge application.

### Consequences

* Good, because a link between two pieces of knowledge is a fact the store keeps.
* Bad, because the graph database is one more thing to run.
MD
cat > features/support/file-an-article.feature <<'FEATURE'
@id:file-an-article
Feature: File an article

  An engineer who solved a problem files it, so the next one does not start from nothing.

  Scenario: An article is filed with how a problem shows and what to do
    Given "GPU runs hot" shows as clocks below 1 GHz under load
    When "grace" files it with "Run the heat test, and replace the GPU if it throttles"
    Then "GPU runs hot" can be looked up
FEATURE
git add . && git commit -qm "feat: articles can be filed"
git switch -q -c slice
cat > features/support/an-article-names-its-procedure.feature <<'FEATURE'
@id:an-article-names-its-procedure
Feature: An article names the procedure that resolves it

  What to do lives in a procedure, so an article points at it instead of retelling its steps.

  Rule: An article names its procedure, or asks for one

    Scenario: An article names the procedure that resolves it
      Given the procedure "Replace a throttling GPU"
      When "grace" files "GPU runs hot" resolved by "Replace a throttling GPU"
      Then an engineer reading "GPU runs hot" is led to "Replace a throttling GPU"

    Scenario: An article with nothing to do is refused
      When "grace" files "GPU runs hot" with no procedure and no question
      Then "grace" is told to name the procedure, or ask for one, and nothing is filed
FEATURE
git add . && git commit -qm "spec: an article names the procedure that resolves it"
