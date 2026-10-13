#!/usr/bin/env bash
# The shop's first sign-in: how staff authenticate binds every feature that follows, so it may warrant an ADR — but only with the driver's yes.
set -euo pipefail
git init -q -b main
git config user.email eval@example.com
git config user.name eval
mkdir -p docs/architecture/models docs/architecture/views docs/adrs
cat > docs/architecture/likec4.config.mjs <<'MJS'
import { defineConfig } from 'likec4/config'
export default defineConfig({ name: 'shop', metadata: { description: 'A web shop: the storefront and the orders it takes.' } })
MJS
cat > docs/architecture/models/base-model.c4 <<'C4'
specification {
  element person
  element system
  element application
  element external
}
model {
  customer = person 'Customer' 'Buys from the shop.'
  staff = person 'Staff' 'Runs the shop.'
  shop = system 'Shop' {
    storefront = application 'Storefront' 'The web pages customers and staff use.'
    orders = application 'Orders' 'Takes, ships and tracks orders.'
  }
  carrier = external 'Carrier' 'Delivers parcels and reports when they will arrive.'
  customer -> shop.storefront 'browses and orders'
  staff -> shop.storefront 'manages orders'
  shop.storefront -> shop.orders 'places and reads orders'
  shop.orders -> carrier 'books deliveries and reads their status'
}
C4
cat > docs/architecture/views/views.c4 <<'C4'
views {
  view context {
    title 'Context'
    include *
  }
  view shop of shop {
    title 'Shop'
    include *
  }
}
C4
git add . && git commit -qm "arch: the shop takes orders and books deliveries"
git switch -q -c slice
mkdir -p "$(dirname features/staff/sign-in.feature)"
cat > features/staff/sign-in.feature <<'FEATURE'
@id:staff-sign-in
Feature: Staff sign in with their company account

  Staff use the account they already have, so nobody manages a second password.

  Scenario: A member of staff signs in with their company account
    Given "grace" has the company account "grace@shop.example"
    When "grace" signs in to the storefront
    Then "grace" sees the orders to manage

  Scenario: Someone outside the company is turned away
    Given "mallory" has the account "mallory@elsewhere.example"
    When "mallory" signs in to the storefront
    Then "mallory" is told only staff may sign in, and sees no orders
FEATURE
git add . && git commit -qm "spec: staff sign in with their company account"
