#!/usr/bin/env bash
# A users service whose slice only renames an internal helper, with no change in behaviour.
set -euo pipefail
git init -q -b main
git config user.email eval@example.com
git config user.name eval
mkdir -p src features/users docs/architecture/models
cat > src/auth.js <<'JS'
function requireAdmin(req, res, next) {
  if (req.user && req.user.role === 'admin') return next();
  res.status(403).json({ error: 'forbidden' });
}
module.exports = { requireAdmin };
JS
cat > src/server.js <<'JS'
const express = require('express');
const { requireAdmin } = require('./auth');
const users = require('./users');
const app = express();
app.use(express.json());
app.get('/users/:id', (req, res) => res.json(users.find(req.params.id)));
app.post('/users', requireAdmin, (req, res) => res.status(201).json(users.create(req.body)));
module.exports = app;
JS
cat > src/users.js <<'JS'
const store = new Map();
module.exports = {
  find: (id) => store.get(id),
  create: (user) => { store.set(user.id, user); return user; },
};
JS
cat > docs/architecture/models/base-model.c4 <<'C4'
model {
  api = application 'Users API' 'Creates, reads and deletes users.'
}
C4
git add . && git commit -qm "feat: users can be created and read"
git switch -q -c slice
cat > features/users/read-user.feature <<'FEATURE'
@id:read-user
Feature: Read a user

  Rule: Anyone reads a user by id

    Scenario: A user is read by id
      Given a user "ada" exists
      When "ada" is read
      Then the user's details are returned
FEATURE
git add . && git commit -qm "spec: a user is read by id"
sed -i 's/store/usersById/g' src/users.js
git add . && git commit -qm "refactor: the store says what it is keyed by"
git diff main..slice > slice.diff
