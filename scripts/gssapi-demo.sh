#!/bin/sh
# Guided walkthrough for GSSAPI/Kerberos SSH auth. Run from the repo root,
# on the machine running docker compose (not inside a container), same
# reasoning as every other scripts/*-demo.sh in this repo.
#
#   ./scripts/gssapi-demo.sh
#
# Brings the gssapi/ stack up itself. Does not `set -e`: two steps are
# supposed to fail (no ticket yet, then ticket destroyed), and the point
# is to see and explain why.

set -u
cd "$(dirname "$0")/.."

COMPOSE="docker compose -f gssapi/docker-compose.yml"
SSH="ssh -o ConnectTimeout=5 -o PreferredAuthentications=gssapi-with-mic"

section() {
    echo
    echo "############################################################"
    echo "# $1"
    echo "############################################################"
}

section "0. bring the gssapi stack up"
$COMPOSE up --build -d
sleep 3

section "1. alice -> web01, no ticket yet [expect: DENIED]"
echo "\$ ssh alice@web01"
$COMPOSE exec client $SSH alice@web01 'echo should not print'
echo "  -> denied. No key, no certificate anywhere in this chapter - just"
echo "     no proof yet of who alice is."

section "2. get a ticket"
echo "\$ kinit alice   (password: alicepassword)"
$COMPOSE exec -T client sh -c "echo alicepassword | kinit alice"
echo "\$ klist"
$COMPOSE exec client klist

section "3. alice -> web01, with a ticket [expect: SUCCESS]"
echo "\$ ssh alice@web01"
$COMPOSE exec client $SSH alice@web01 \
    'echo "  -> logged in to $(hostname) as $(whoami), via GSSAPI"'
echo "  -> web01 has PubkeyAuthentication and PasswordAuthentication both"
echo "     turned off (see gssapi/web01/entrypoint.sh) - GSSAPI is"
echo "     provably the only way in, not just the one we happened to use."

section "4. destroy the ticket"
echo "\$ kdestroy"
$COMPOSE exec client kdestroy
echo "\$ klist"
$COMPOSE exec client klist || true

section "5. alice -> web01, ticket gone [expect: DENIED again]"
echo "\$ ssh alice@web01"
$COMPOSE exec client $SSH alice@web01 'echo should not print'
echo "  -> denied. The ticket - not a stored key, not a certificate - was"
echo "     what mattered, and it's gone."

section "6. compare to certificates (chapters 0-4)"
cat <<'EOF'
There, YOU hold a long-lived key pair, and a short-lived CERTIFICATE
wrapping it is the disposable part - proof stays local, checked against a
CA's public key that can be trusted completely offline. Here, there is no
local key pair at all: the disposable thing is a TICKET, obtained by
proving your password to a single, centrally trusted KDC - one that every
host must be able to reach live, at connection time, not just at setup
time. Different trade-offs, same underlying goal: nobody wants a
long-lived secret sitting on every host.
EOF

echo
echo "Done. See docs/gssapi.md for the kinit/klist/kdestroy/ktadd reference."
echo "Tear down: docker compose -f gssapi/docker-compose.yml down -v"
