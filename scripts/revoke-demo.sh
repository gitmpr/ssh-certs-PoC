#!/bin/sh
# Guided walkthrough for certificate revocation. Run from the repo root, on
# the machine running docker compose (not inside a container) - it needs
# `docker compose run` for the CA and `docker compose exec` for the client,
# neither of which is available from inside another container without
# mounting the docker socket, which this PoC deliberately doesn't do.
#
#   docker compose up --build -d      # bring the main stack up first
#   ./scripts/revoke-demo.sh
#
# Does not `set -e`: the whole point of step 3 is a connection that's
# supposed to fail.

set -u
cd "$(dirname "$0")/.."

SSH="ssh -o ConnectTimeout=5"

section() {
    echo
    echo "############################################################"
    echo "# $1"
    echo "############################################################"
}

section "1. carol (principal: dba) -> db01, before revocation [expect: SUCCESS]"
echo "\$ ssh -i carol dba@db01"
docker compose exec client $SSH -i /root/.ssh/carol dba@db01 \
    'echo "  -> logged in to $(hostname) as $(whoami)"'

section "2. revoke carol's certificate"
echo "\$ docker compose run --rm --entrypoint /usr/local/bin/revoke.sh ca carol"
docker compose run --rm --entrypoint /usr/local/bin/revoke.sh ca carol

section "3. carol (principal: dba) -> db01, after revocation [expect: DENIED]"
echo "\$ ssh -i carol dba@db01"
docker compose exec client $SSH -i /root/.ssh/carol dba@db01 \
    'echo "  -> should not print"'
echo "  -> denied. Nothing on db01 was touched: no restart, no config"
echo "     push, no edited file copied out to a host. db01's sshd reads"
echo "     RevokedKeys straight off the shared volume on every connection,"
echo "     so revocation took effect the instant revoke.sh finished."

section "4. this was not an expiry - the certificate is still otherwise valid"
echo "\$ ssh-keygen -Lf /root/.ssh/carol-cert.pub"
docker compose exec client ssh-keygen -Lf /root/.ssh/carol-cert.pub
echo
echo "Notice the Valid: window above has not elapsed. Revocation and"
echo "expiry are two independent mechanisms - see docs/cheatsheet.md."

section "5. alice is unaffected"
echo "\$ ssh -i alice ops@web01"
docker compose exec client $SSH -i /root/.ssh/alice ops@web01 \
    'echo "  -> logged in to $(hostname) as $(whoami)"'
echo "  -> only carol's certificate was named in the KRL. Revocation is"
echo "     per-identity, not a blunt instrument."

echo
echo "Done. See docs/validation.md and README.md for what this demonstrates."
