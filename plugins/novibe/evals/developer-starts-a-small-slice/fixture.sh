#!/usr/bin/env bash
# The same refund feature, with the partial-refund rule tagged @backlog: the slice is one rule, two scenarios.
set -euo pipefail
git init -q -b main
git config user.email eval@example.com
git config user.name eval
mkdir -p src features/orders docs/architecture/models
cat > src/orders.js <<'JS'
const orders = new Map();
module.exports = {
  pay: (id, customer, amount) => orders.set(id, { customer, amount, paidAt: Date.now() }),
  find: (id) => orders.get(id),
};
JS
cat > docs/architecture/models/base-model.c4 <<'C4'
model {
  shop = application 'Shop' 'Takes orders and payments.'
}
C4
git add . && git commit -qm "feat: orders can be paid"
git switch -q -c slice
cat > features/orders/refund-an-order.feature <<'FEATURE'
@id:refund-an-order
Feature: Refund an order

  A customer who changed their mind gets their money back, so they buy again without worry.

  Rule: A customer is refunded in full within 30 days

    Scenario: A refund on day 12 is paid in full
      Given "ada" paid 40.00 EUR for order "A-17" 12 days ago
      When "ada" asks for a refund of "A-17"
      Then "ada" is refunded 40.00 EUR

    Scenario: A refund on day 31 is refused
      Given "ada" paid 40.00 EUR for order "A-17" 31 days ago
      When "ada" asks for a refund of "A-17"
      Then "ada" is told the 30 days have passed, and nothing is refunded

  Rule: A partial refund keeps the rest charged

    @backlog
    Scenario: Two of three items are returned
      Given "ada" paid 30.00 EUR for 3 mugs in order "B-4"
      When "ada" returns 2 mugs
      Then "ada" is refunded 20.00 EUR and still pays 10.00 EUR

    @backlog
    Scenario: The last item is returned later
      Given "ada" kept 1 mug of order "B-4" for 10.00 EUR
      When "ada" returns it 5 days later
      Then "ada" is refunded 10.00 EUR

    @backlog
    Scenario: More items than were bought are returned
      Given "ada" bought 3 mugs in order "B-4"
      When "ada" returns 4 mugs
      Then "ada" is told only 3 were bought, and nothing is refunded
FEATURE
git add . && git commit -qm "spec: a customer is refunded"
