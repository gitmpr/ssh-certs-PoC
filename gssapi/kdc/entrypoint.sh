#!/bin/sh
# The Kerberos KDC (Key Distribution Center). Unlike every CA in this repo
# (which run once and exit), this is a long-running service: GSSAPI/
# Kerberos auth needs the KDC reachable at connection time, not just at
# setup time - a genuinely different trust model from "trust a signature
# once, offline" (see the README for the full contrast).
#
# On first start: creates the realm database, then two principals -
# alice@REALM (a human, authenticates with a password) and
# host/web01@REALM (a service identity, authenticates with a keytab -
# see docs/gssapi.md for why humans and hosts get different credential
# types). web01's keytab is exported to the shared volume so web01's sshd
# can use it without ever talking to kadmin itself.

set -eu

SHARED=/shared
REALM=SSHCERTS.LOCAL
ALICE_PASSWORD=alicepassword

if [ ! -f "$SHARED/.ready" ]; then
    echo "==> creating realm $REALM"
    kdb5_util create -s -r "$REALM" -P "disposable-demo-master-key"

    echo "==> creating principals"
    kadmin.local -q "addprinc -pw $ALICE_PASSWORD alice@$REALM"
    kadmin.local -q "addprinc -randkey host/web01@$REALM"

    echo "==> exporting web01's host keytab"
    mkdir -p "$SHARED/keytabs"
    kadmin.local -q "ktadd -k $SHARED/keytabs/web01.keytab host/web01@$REALM"
    chmod a+r "$SHARED/keytabs/web01.keytab"

    touch "$SHARED/.ready"
fi

echo "==> starting krb5kdc"
# kadmind (remote admin) is deliberately not run here - nothing in this
# demo talks to it. kadmin.local, used above, operates directly on the
# database file and needs no running daemon or ACL file; kinit only ever
# talks to krb5kdc itself.
exec krb5kdc -n
