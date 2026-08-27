#!/bin/sh
# Generic "server" entrypoint, parameterised by HOST_NAME and
# ALLOWED_PRINCIPAL so the same image serves as web01, db01, or any other
# host you add to docker-compose.yml.
#
# What this sets up, and why it matters:
#
#   HostKey / HostCertificate
#       This host proves its identity with a certificate signed by the CA,
#       instead of clients having to learn and remember its raw host key
#       (the thing behind the "authenticity of host ... can't be
#       established" prompt and known_hosts sprawl).
#
#   TrustedUserCAKeys
#       This host accepts *any* user certificate signed by the CA, instead
#       of needing every user's public key copied into authorized_keys and
#       kept in sync as people join, leave, or rotate keys.
#
#   AuthorizedPrincipalsFile
#       Trusting the CA is not the same as trusting everyone it has ever
#       signed for. This file is the per-host, per-account authorization
#       policy: it says which certificate *principals* (roles) may log in
#       as which local account. Only ALLOWED_PRINCIPAL gets an entry here,
#       so a perfectly valid, CA-signed certificate for the wrong role is
#       still refused.

set -eu

NAME="${HOST_NAME:?HOST_NAME not set}"
ALLOWED="${ALLOWED_PRINCIPAL:?ALLOWED_PRINCIPAL not set}"
SHARED=/shared
SRC="$SHARED/hosts/$NAME"

echo "==> waiting for CA material"
until [ -f "$SHARED/.ready" ]; do
    sleep 1
done

cp "$SRC/ssh_host_ed25519_key" /etc/ssh/ssh_host_ed25519_key
cp "$SRC/ssh_host_ed25519_key-cert.pub" /etc/ssh/ssh_host_ed25519_key-cert.pub
cp "$SHARED/ca/ca_key.pub" /etc/ssh/user_ca.pub
chmod 600 /etc/ssh/ssh_host_ed25519_key
chmod 644 /etc/ssh/ssh_host_ed25519_key-cert.pub /etc/ssh/user_ca.pub

mkdir -p /etc/ssh/auth_principals
echo "$ALLOWED" > "/etc/ssh/auth_principals/$ALLOWED"

cat >> /etc/ssh/sshd_config <<EOF

# --- ssh-certs-PoC ---
HostKey /etc/ssh/ssh_host_ed25519_key
HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
TrustedUserCAKeys /etc/ssh/user_ca.pub
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF

echo "==> $NAME ready (accepts principal '$ALLOWED'), starting sshd"
exec /usr/sbin/sshd -D -e
