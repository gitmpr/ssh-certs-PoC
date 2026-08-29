#!/bin/sh
# GSSAPI-only sshd: PubkeyAuthentication and PasswordAuthentication are
# both off, so a successful login here can only ever have happened via a
# Kerberos ticket - nothing else is even offered.

set -eu

SHARED=/shared

echo "==> waiting for KDC realm setup"
until [ -f "$SHARED/.ready" ]; do
    sleep 1
done

cp "$SHARED/keytabs/web01.keytab" /etc/krb5.keytab
chmod 600 /etc/krb5.keytab

cat >> /etc/ssh/sshd_config <<EOF

# --- ssh-certs-PoC (gssapi) ---
GSSAPIAuthentication yes
GSSAPICleanupCredentials yes
GSSAPIStrictAcceptorCheck no
PubkeyAuthentication no
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF

echo "==> web01 ready (GSSAPI is the only auth method offered), starting sshd"
exec /usr/sbin/sshd -D -e
