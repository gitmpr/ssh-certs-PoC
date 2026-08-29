#!/bin/sh
# Trusts both environments' CAs for host verification. Nothing else is
# pre-provisioned - unlike chapters 0-3, where alice/carol/dan's user
# certificates already exist by the time the client is ready, nothing
# here exists until issue.sh is called, on demand, for a specific
# environment.

set -eu

SHARED=/shared

echo "==> waiting for CA material"
until [ -f "$SHARED/.ready" ]; do
    sleep 1
done

mkdir -p /root/.ssh
chmod 700 /root/.ssh

{
    echo "@cert-authority * $(cat "$SHARED/staging/ca/ca_key.pub")"
    echo "@cert-authority * $(cat "$SHARED/prod/ca/ca_key.pub")"
} > /etc/ssh/ssh_known_hosts

cat <<'EOF'
==> client ready

No certificates are pre-issued in this stack - request one on demand, then
connect using it explicitly:

    docker compose run --rm --entrypoint /usr/local/bin/issue.sh ca staging alice ops 2m
    ssh -o CertificateFile=/shared/users/alice/id_ed25519.staging-cert.pub \
        -i /shared/users/alice/id_ed25519 ops@staging-web01

See scripts/short-lived-demo.sh for the guided walkthrough.
EOF

exec tail -f /dev/null
