#!/bin/sh
# Guided walkthrough. Run with: docker compose exec client demo.sh
#
# Intentionally does not `set -e`: step 3 is supposed to fail, and the
# script should keep going and explain why.

set -u
SSH="ssh -o ConnectTimeout=5"

section() {
    echo
    echo "############################################################"
    echo "# $1"
    echo "############################################################"
}

section "1. alice (principal: ops) -> web01  [expect: SUCCESS]"
echo "\$ ssh -i alice ops@web01"
$SSH -i /root/.ssh/alice ops@web01 'echo "  -> logged in to $(hostname) as $(whoami)"'

section "2. carol (principal: dba) -> db01   [expect: SUCCESS]"
echo "\$ ssh -i carol dba@db01"
$SSH -i /root/.ssh/carol dba@db01 'echo "  -> logged in to $(hostname) as $(whoami)"'

section "3. alice (principal: ops) -> db01   [expect: DENIED]"
echo "\$ ssh -i alice dba@db01"
$SSH -i /root/.ssh/alice dba@db01 'echo "  -> should not print"'
echo "  -> denied as expected: alice's certificate carries principal 'ops',"
echo "     and db01 only lists 'dba' in its AuthorizedPrincipalsFile."
echo "     The certificate is perfectly valid and CA-signed - it is simply"
echo "     not authorized for this account. Authentication != authorization."

section "4. host trust, without ever touching known_hosts by hand"
echo "None of the connections above prompted:"
echo "  \"The authenticity of host ... can't be established\""
echo "That's because /etc/ssh/ssh_known_hosts holds one @cert-authority line"
echo "for our CA, valid for every host ('*'). Compare to plain known_hosts,"
echo "where every host needs its own entry, learned via a first-connection"
echo "leap of faith (TOFU) or copied around out of band."

section "5. inspect a certificate"
echo "\$ ssh-keygen -Lf /root/.ssh/alice-cert.pub"
ssh-keygen -Lf /root/.ssh/alice-cert.pub

echo
echo "Done. See the README for what each of these fields means."
