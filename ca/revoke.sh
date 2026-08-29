#!/bin/sh
# Revoke a previously-issued user certificate by username.
#
#   docker compose run --rm --entrypoint /usr/local/bin/revoke.sh ca carol
#
# Updates the shared Key Revocation List (KRL) at $SHARED/ca/revoked.krl.
# Every host's sshd points its RevokedKeys directive straight at that file
# on the shared volume (see hosts/entrypoint.sh) - it's read fresh on every
# connection attempt, so the moment this script finishes, every host
# rejects the revoked identity on its very next connection. No host
# restart, no redistribution step, no per-host edit.
#
# Revocation here is by key ID (the -I string given at signing time, e.g.
# "user_carol" - see ca/entrypoint.sh), not by serial number: every
# certificate this repo issues uses serial 0, so key ID is what actually
# distinguishes one identity's certificate from another's.

set -eu

USER="${1:?usage: revoke.sh <username>}"
SHARED=/shared
CA_DIR="$SHARED/ca"
CERT="$SHARED/users/$USER/id_ed25519-cert.pub"
KRL="$CA_DIR/revoked.krl"
VERSION_FILE="$CA_DIR/.krl_version"

[ -f "$CERT" ] || { echo "no such user certificate: $CERT" >&2; exit 1; }

# The KRL version number just needs to increase on every update; sshd
# doesn't require it, but ssh-keygen wants it when updating an existing KRL
# in place so that a KRL never appears to move backwards in time.
version=1
[ -f "$VERSION_FILE" ] && version=$(($(cat "$VERSION_FILE") + 1))

spec=$(mktemp)
echo "id: user_$USER" > "$spec"

ssh-keygen -k -f "$KRL" -u -s "$CA_DIR/ca_key.pub" -z "$version" "$spec"
rm -f "$spec"
echo "$version" > "$VERSION_FILE"
chmod a+r "$KRL"

echo "==> revoked user_$USER (KRL version $version)"

# ssh-keygen -Q exits 0 ("ok") when the key is NOT in the KRL, and non-zero
# ("REVOKED") when it is - inverted from what you'd naively expect.
if ssh-keygen -Qf "$KRL" "$CERT"; then
    echo "==> WARNING: ssh-keygen -Q does not report $CERT as revoked" >&2
    exit 1
else
    echo "==> confirmed: $CERT is now rejected by any host trusting this KRL"
fi
