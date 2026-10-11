#!/usr/bin/env bash
# A users service whose slice adds a delete endpoint without the admin check the other admin routes have.
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
cat > features/users/delete-user.feature <<'FEATURE'
@id:delete-user
Feature: Delete a user

  Rule: An admin removes a user for good

    Scenario: An admin deletes a user
      Given a user "ada" exists
      When an admin deletes "ada"
      Then "ada" no longer exists
FEATURE
git add . && git commit -qm "spec: an admin deletes a user"
cat > src/users.js <<'JS'
const store = new Map();
module.exports = {
  find: (id) => store.get(id),
  create: (user) => { store.set(user.id, user); return user; },
  remove: (id) => store.delete(id),
};
JS
sed -i "s|^module.exports = app;|app.delete('/users/:id', (req, res) => { users.remove(req.params.id); res.status(204).end(); });\nmodule.exports = app;|" src/server.js
git add . && git commit -qm "feat: an admin deletes a user"
git diff main..slice > slice.diff
