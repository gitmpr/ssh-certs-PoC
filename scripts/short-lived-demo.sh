#!/bin/sh
# Guided walkthrough for on-demand, short-lived issuance against chapter
# 0's single CA. Run from the repo root, on the machine running docker
# compose (not inside a container) - needs `docker compose run` for the
# CA and `docker compose exec` for the client, same reasoning as
# scripts/revoke-demo.sh.
#
#   docker compose up --build -d      # chapter 0 stack must already be running
#   ./scripts/short-lived-demo.sh
#
# Does not `set -e`: the last step is supposed to fail (expiry). Runs a
# little over two minutes - the expiry step genuinely waits it out rather
# than asserting it, the same technique used in chapter 4.

set -u
cd "$(dirname "$0")/.."

SSH="ssh -o ConnectTimeout=5"
KEY=/shared/users/dan/id_ed25519
TTL=2m

section() {
    echo
    echo "############################################################"
    echo "# $1"
    echo "############################################################"
}

section "1. request a short-lived certificate for dan (ttl: $TTL)"
echo "\$ issue.sh dan ops $TTL"
docker compose run --rm --entrypoint /usr/local/bin/issue.sh ca dan ops "$TTL"

section "2. dan -> web01 [expect: SUCCESS]"
echo "\$ ssh -i dan-key ops@web01"
docker compose exec client $SSH -i $KEY ops@web01 \
    'echo "  -> logged in to $(hostname) as $(whoami)"'
echo "  -> dan never had a certificate before this demo ran. alice and"
echo "     carol (chapters 0-2) got theirs pre-issued once, at CA"
echo "     startup, valid for 8 hours. dan's was minted on demand, for"
echo "     $TTL, by a single issue.sh call - no different in kind from"
echo "     what a real signing service (step-ca, Vault, ...) does"
echo "     automatically on every login. See docs/production.md."

section "3. waiting out dan's certificate's $TTL validity window"
echo "(sleeping 125s so it actually expires - not taking it on faith)"
sleep 125
echo "\$ ssh -i dan-key ops@web01   [expect: DENIED - expired]"
docker compose exec client $SSH -i $KEY ops@web01 'echo should not print'
echo "  -> denied. Compare to chapter 2's scripts/revoke-demo.sh: there,"
echo "     someone had to actively decide to kill carol's certificate."
echo "     Here nobody did anything - dan's certificate simply ran out of"
echo "     the validity it was minted with. Pushed short enough, this"
echo "     gets you most of what revocation buys you without needing a"
echo "     revocation mechanism at all - see docs/production.md."

echo
echo "Done. See docs/cheatsheet.md and docs/production.md for more."
