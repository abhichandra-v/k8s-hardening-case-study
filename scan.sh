#!/usr/bin/env bash
# Reproduce the before/after security scan numbers in CASE-STUDY.md.
# Requires: kube-score (https://github.com/zegl/kube-score) and
#           checkov (pip install checkov).
set -uo pipefail
cd "$(dirname "$0")"

BEFORE="before/deployment.yaml before/service.yaml"
AFTER="after/namespace.yaml after/deployment.yaml after/service.yaml after/networkpolicy.yaml after/pdb.yaml"

crit() { kube-score score $1 2>/dev/null | grep -c '\[CRITICAL\]'; }
warn() { kube-score score $1 2>/dev/null | grep -c '\[WARNING\]'; }

echo "================  kube-score  ================"
printf "  before : %s CRITICAL, %s WARNING\n" "$(crit "$BEFORE")" "$(warn "$BEFORE")"
printf "  after  : %s CRITICAL, %s WARNING\n" "$(crit "$AFTER")" "$(warn "$AFTER")"

echo
echo "==================  checkov  ================="
echo "  before:"; checkov -d before --framework kubernetes --compact --quiet 2>/dev/null | grep -E 'Passed checks|Failed checks' | sed 's/^/    /'
echo "  after:";  checkov -d after  --framework kubernetes --compact --quiet 2>/dev/null | grep -E 'Passed checks|Failed checks' | sed 's/^/    /'

echo
echo "Done. These are the numbers in CASE-STUDY.md."
