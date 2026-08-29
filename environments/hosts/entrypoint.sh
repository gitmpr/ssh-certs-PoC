#!/bin/sh
# Generic host entrypoint, parameterised by ENV, HOST_NAME, and
# ALLOWED_PRINCIPAL - the same image serves staging-web01 and prod-web01.
#
# The one line that matters for environment isolation is
# TrustedUserCAKeys: it names only this environment's CA public key, never
# the other one's. A certificate that is otherwise perfect - CA-signed,
# unexpired, right principal - issued by the WRONG environment's CA is
# simply not signed by anyone this host has ever heard of, and is refused
# before AuthorizedPrincipalsFile even gets consulted.

set -eu

ENV="${ENV:?ENV not set}"
NAME="${HOST_NAME:?HOST_NAME not set}"
ALLOWED="${ALLOWED_PRINCIPAL:?ALLOWED_PRINCIPAL not set}"
SHARED=/shared
SRC="$SHARED/$ENV/hosts/$NAME"
CA_DIR="$SHARED/$ENV/ca"

echo "==> waiting for CA material"
until [ -f "$SHARED/.ready" ]; do
    sleep 1
done

cp "$SRC/ssh_host_ed25519_key" /etc/ssh/ssh_host_ed25519_key
cp "$SRC/ssh_host_ed25519_key-cert.pub" /etc/ssh/ssh_host_ed25519_key-cert.pub
cp "$CA_DIR/ca_key.pub" /etc/ssh/user_ca.pub
chmod 600 /etc/ssh/ssh_host_ed25519_key
chmod 644 /etc/ssh/ssh_host_ed25519_key-cert.pub /etc/ssh/user_ca.pub

mkdir -p /etc/ssh/auth_principals
echo "$ALLOWED" > "/etc/ssh/auth_principals/$ALLOWED"

cat >> /etc/ssh/sshd_config <<EOF

# --- ssh-certs-PoC (environment: $ENV) ---
HostKey /etc/ssh/ssh_host_ed25519_key
HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
TrustedUserCAKeys /etc/ssh/user_ca.pub
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF

echo "==> $NAME ready ($ENV environment, trusts only the $ENV CA), starting sshd"
exec /usr/sbin/sshd -D -e
