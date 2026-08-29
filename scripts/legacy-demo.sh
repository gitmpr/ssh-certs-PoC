#!/bin/sh
# Guided walkthrough of the classic (no-CA) model, for direct comparison
# against scripts/revoke-demo.sh and the main stack. Run from the repo
# root, on the machine running docker compose:
#
#   ./scripts/legacy-demo.sh
#
# Brings the legacy/ stack up itself. Does not `set -e`: several steps are
# supposed to fail, and the point is to see and explain the failure.

set -u
cd "$(dirname "$0")/.."

COMPOSE="docker compose -f legacy/docker-compose.yml"
SSH="ssh -o ConnectTimeout=5"
CLIENT_KEY=/root/.ssh/id_ed25519

section() {
    echo
    echo "############################################################"
    echo "# $1"
    echo "############################################################"
}

section "0. bring the legacy stack up"
$COMPOSE up --build -d
sleep 2

section "1. nothing is trusted yet [expect: DENIED everywhere]"
echo "\$ ssh ops@legacy-web01"
$COMPOSE exec legacy-client $SSH -o StrictHostKeyChecking=accept-new \
    -i $CLIENT_KEY ops@legacy-web01 'echo should not print'
echo "  -> denied: legacy-web01's authorized_keys for 'ops' is empty."
echo "     No certificate, no CA, nothing to authorize this key anywhere yet."

section "2. grant access on legacy-web01 (host #1 of 2)"
PUBKEY=$($COMPOSE exec -T legacy-client cat "${CLIENT_KEY}.pub")
echo "\$ (append client pubkey to /home/ops/.ssh/authorized_keys on legacy-web01)"
$COMPOSE exec -T legacy-web01 sh -c "echo '$PUBKEY' >> /home/ops/.ssh/authorized_keys"
echo "\$ ssh ops@legacy-web01"
$COMPOSE exec legacy-client $SSH -o StrictHostKeyChecking=accept-new \
    -i $CLIENT_KEY ops@legacy-web01 'echo "  -> logged in to $(hostname) as $(whoami)"'

section "3. grant access on legacy-db01 (host #2 of 2) - the exact same step, again"
echo "\$ (append the SAME client pubkey to /home/dba/.ssh/authorized_keys on legacy-db01)"
$COMPOSE exec -T legacy-db01 sh -c "echo '$PUBKEY' >> /home/dba/.ssh/authorized_keys"
echo "\$ ssh dba@legacy-db01"
$COMPOSE exec legacy-client $SSH -o StrictHostKeyChecking=accept-new \
    -i $CLIENT_KEY dba@legacy-db01 'echo "  -> logged in to $(hostname) as $(whoami)"'
echo "  -> two hosts, two manual edits. Compare to the main stack, where"
echo "     trusting a new CA-signed identity takes zero per-host edits."

section "4. legacy-web01 gets rebuilt (simulated) - its host identity changes"
echo "\$ docker compose up -d --force-recreate legacy-web01"
$COMPOSE up -d --force-recreate legacy-web01 >/dev/null
sleep 2
echo "\$ ssh ops@legacy-web01   [expect: REFUSED, host key mismatch]"
$COMPOSE exec legacy-client $SSH -i $CLIENT_KEY ops@legacy-web01 'echo should not print'
echo "  -> refused before authentication even starts: known_hosts has the"
echo "     OLD host key, the rebuilt container presents a NEW one. This is"
echo "     the exact failure host certificates eliminate (docs/validation.md)."
echo "     authorized_keys on legacy-web01 survived the rebuild (separate"
echo "     volume) - only the host's own identity changed."

section "5. fixing the mismatch by hand"
echo "\$ ssh-keygen -R legacy-web01 -f ~/.ssh/known_hosts"
$COMPOSE exec legacy-client ssh-keygen -R legacy-web01 -f /root/.ssh/known_hosts
echo "\$ ssh ops@legacy-web01"
$COMPOSE exec legacy-client $SSH -o StrictHostKeyChecking=accept-new \
    -i $CLIENT_KEY ops@legacy-web01 'echo "  -> logged in to $(hostname) as $(whoami)"'
echo "  -> works again, but only because someone noticed and fixed it here."
echo "     At real fleet size, this is the known_hosts sprawl problem."

section "6. revoking access the old way: found and fixed on ONE host, forgotten on the other"
echo "\$ (remove the key from legacy-web01's authorized_keys only)"
$COMPOSE exec -T legacy-web01 sh -c '> /home/ops/.ssh/authorized_keys'
echo "\$ ssh ops@legacy-web01   [expect: DENIED]"
$COMPOSE exec legacy-client $SSH -i $CLIENT_KEY ops@legacy-web01 'echo should not print'
echo "\$ ssh dba@legacy-db01    [expect: STILL WORKS - nobody remembered this one]"
$COMPOSE exec legacy-client $SSH -i $CLIENT_KEY dba@legacy-db01 \
    'echo "  -> logged in to $(hostname) as $(whoami)"'
echo "  -> this is the gap scripts/revoke-demo.sh closes: one KRL update,"
echo "     read live by every host, versus hunting down every host a key"
echo "     was ever pasted to and hoping none were missed."

echo
echo "Done. See docs/comparison.md for the write-up."
echo "Tear down: docker compose -f legacy/docker-compose.yml down -v"
