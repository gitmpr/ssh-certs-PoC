#!/bin/sh
# Issue a short-lived user certificate on demand, against this chapter's
# single CA - rather than pre-issuing everything at CA startup the way
# alice/carol get theirs (see entrypoint.sh, chapter 0).
#
#   docker compose run --rm --entrypoint /usr/local/bin/issue.sh ca dan ops 2m
#
# The user's key PAIR is created once and reused forever - it's inert,
# there's nothing to rotate about a public/private key on its own. What's
# short-lived and gets reissued is the CERTIFICATE wrapping it: a fresh
# signature, a fresh (short) validity window, every time this runs.
#
# Writes into a brand-new identity (e.g. "dan") rather than touching
# alice/carol's already pre-issued certificates, so chapters 0-2's demos
# (demo.sh, revoke-demo.sh) keep working completely unmodified.

set -eu

USER="${1:?usage: issue.sh <username> <principal> [ttl, default 2m]}"
PRINCIPAL="${2:?usage: issue.sh <username> <principal> [ttl, default 2m]}"
TTL="${3:-2m}"

SHARED=/shared
CA_DIR="$SHARED/ca"
USER_DIR="$SHARED/users/$USER"

mkdir -p "$USER_DIR"
if [ ! -f "$USER_DIR/id_ed25519" ]; then
    echo "==> generating long-lived key pair for $USER (first issuance ever)"
    ssh-keygen -t ed25519 -f "$USER_DIR/id_ed25519" -C "$USER" -N ""
fi

echo "==> issuing certificate for $USER (principal: $PRINCIPAL, ttl: $TTL)"
ssh-keygen -s "$CA_DIR/ca_key" \
    -I "user_${USER}_$(date +%s)" \
    -n "$PRINCIPAL" \
    -V "+$TTL" \
    "$USER_DIR/id_ed25519.pub"

chmod a+r "$USER_DIR/id_ed25519.pub" "$USER_DIR/id_ed25519-cert.pub"

echo "==> issued: $USER_DIR/id_ed25519-cert.pub"
ssh-keygen -Lf "$USER_DIR/id_ed25519-cert.pub"
