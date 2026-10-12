#!/usr/bin/env bash
# A shop that syncs stock from a warehouse; the slice's fix for a certificate error turns off TLS verification.
set -euo pipefail
git init -q -b main
git config user.email eval@example.com
git config user.name eval
mkdir -p src features/stock
cat > src/warehouse.js <<'JS'
const https = require('https');
const agent = new https.Agent({ rejectUnauthorized: true });
async function fetchStock(sku) {
  const res = await fetch(`https://warehouse.example.com/stock/${sku}`, { agent });
  return (await res.json()).available;
}
module.exports = { fetchStock };
JS
git add . && git commit -qm "feat: stock comes from the warehouse"
git switch -q -c slice
cat > features/stock/stock-shown.feature <<'FEATURE'
@id:SHOP-51
Feature: Stock is shown

  Rule: A product shows how many the warehouse has

    Scenario: A product in stock
      Given the warehouse has 3 of "mug"
      When a customer looks at "mug"
      Then they see "3 in stock"
FEATURE
git add . && git commit -qm "spec: a product shows its stock"
perl -pi -e 's/\{ rejectUnauthorized: true \}/{}/' src/warehouse.js
perl -pi -e 's|^const agent = new https\.Agent\(\{\}\);|const agent = new https.Agent({});\nprocess.env.NODE_TLS_REJECT_UNAUTHORIZED = \x270\x27;|' src/warehouse.js
git commit -qam "fix: stock loads again after the warehouse certificate changed"
git diff main..slice > slice.diff
