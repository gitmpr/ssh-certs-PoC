#!/bin/sh
# Issue a short-lived user certificate on demand, against one environment's
# CA.
#
#   docker compose run --rm --entrypoint /usr/local/bin/issue.sh ca \
#       staging alice ops 2m
#
# The user's key PAIR is created once and reused forever - it's inert,
# there's nothing to rotate about a public/private key on its own. What's
# short-lived and gets reissued is the CERTIFICATE wrapping it: a fresh
# signature, a fresh (short) validity window, every time this runs. That
# split - long-lived identity, disposable credential - is what lets a real
# signing service (step-ca, Vault, ...) hand out session-scoped access
# without ever touching the thing the user actually holds onto.
#
# Certificates from different environments must coexist side by side (you
# might legitimately hold both a staging and a prod certificate at once),
# so each environment's certificate is written to its own file rather than
# the default "<key>-cert.pub" name ssh-keygen would otherwise reuse. See
# scripts/short-lived-demo.sh for how `ssh -o CertificateFile=...` picks
# the right one to present for a given connection.

set -eu

ENV="${1:?usage: issue.sh <env> <username> <principal> [ttl, default 2m]}"
USER="${2:?usage: issue.sh <env> <username> <principal> [ttl, default 2m]}"
PRINCIPAL="${3:?usage: issue.sh <env> <username> <principal> [ttl, default 2m]}"
TTL="${4:-2m}"

SHARED=/shared
CA_DIR="$SHARED/$ENV/ca"
USER_DIR="$SHARED/users/$USER"

[ -f "$CA_DIR/ca_key" ] || { echo "no such environment: $ENV" >&2; exit 1; }

mkdir -p "$USER_DIR"
if [ ! -f "$USER_DIR/id_ed25519" ]; then
    echo "==> generating long-lived key pair for $USER (first issuance ever)"
    ssh-keygen -t ed25519 -f "$USER_DIR/id_ed25519" -C "$USER" -N ""
fi

pubkey_copy="$USER_DIR/id_ed25519.$ENV.pub"
cp "$USER_DIR/id_ed25519.pub" "$pubkey_copy"

echo "==> issuing $ENV certificate for $USER (principal: $PRINCIPAL, ttl: $TTL)"
ssh-keygen -s "$CA_DIR/ca_key" \
    -I "user_${USER}_${ENV}_$(date +%s)" \
    -n "$PRINCIPAL" \
    -V "+$TTL" \
    "$pubkey_copy"

chmod a+r "$pubkey_copy" "$USER_DIR/id_ed25519.$ENV-cert.pub"

echo "==> issued: $USER_DIR/id_ed25519.$ENV-cert.pub"
ssh-keygen -Lf "$USER_DIR/id_ed25519.$ENV-cert.pub"
