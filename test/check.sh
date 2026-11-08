#!/usr/bin/env bash
# Model tests, QML syntax, and the plain-text rule for every Text item.
set -u
cd "$(dirname "$0")/.."
fail=0
node --test test/model.test.mjs >/dev/null 2>&1 && echo "ok   model tests" || { echo "FAIL model tests"; fail=1; }
qmllint BarWidget.qml >/dev/null 2>&1 && echo "ok   qmllint" || { echo "FAIL qmllint"; fail=1; }
texts=$(grep -cE '(^|[^A-Za-z])Text \{' BarWidget.qml)
plain=$(grep -c 'textFormat: Text.PlainText' BarWidget.qml)
[ "$texts" -eq "$plain" ] && echo "ok   $texts Text items are PlainText" || { echo "FAIL $texts Text items, $plain PlainText"; fail=1; }
jq -e '.id == "sups.proxyctl"' manifest.json >/dev/null && echo "ok   manifest" || { echo "FAIL manifest"; fail=1; }
exit "$fail"
