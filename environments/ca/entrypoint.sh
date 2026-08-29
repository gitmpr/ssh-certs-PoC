#!/bin/sh
# Issues host certificates for each environment, using the INTERMEDIATE CA
# keys root-ca/ already minted (this service no longer generates its own
# CA key - see environments/root-ca/entrypoint.sh). Unlike main/1_raw_keys,
# no user certificates are issued here up front - see issue.sh for why.
#
# Two separate intermediate CA key pairs (rather than one CA with two sets
# of principals) is the point: a compromise of staging's signing pipeline
# should not be usable to mint anything a prod host will accept. Each
# host's TrustedUserCAKeys names only its own environment's intermediate
# CA public key (see hosts/entrypoint.sh) - that's what makes the
# isolation real rather than conventional.

set -eu

SHARED=/shared
mkdir -p "$SHARED/users"

echo "==> waiting for root CA to mint intermediate keys"
until [ -f "$SHARED/root/.ready" ]; do
    sleep 1
done

for env in staging prod; do
    ca_dir="$SHARED/$env/ca"
    host="${env}-web01"
    host_dir="$SHARED/$env/hosts/$host"
    mkdir -p "$host_dir"

    [ -f "$ca_dir/ca_key" ] || { echo "missing intermediate CA key for $env - root-ca should have minted it" >&2; exit 1; }

    if [ ! -f "$host_dir/ssh_host_ed25519_key" ]; then
        ssh-keygen -t ed25519 -f "$host_dir/ssh_host_ed25519_key" -C "$host" -N ""
    fi

    echo "==> [$env] host certificate for $host"
    ssh-keygen -s "$ca_dir/ca_key" \
        -I "host_${host}" \
        -h \
        -n "$host" \
        -V +52w \
        "$host_dir/ssh_host_ed25519_key.pub"
done

# Scoped to staging/prod/users only - deliberately not $SHARED/root, which
# belongs to root-ca and must never be touched here (a blanket `chmod -R`
# over all of $SHARED previously re-loosened root_key's permissions on
# every run, since this service doesn't know to re-tighten a key it
# doesn't own - ssh-keygen then refused to load it on the next signing
# attempt).
chmod -R a+rX "$SHARED/staging" "$SHARED/prod" "$SHARED/users"
chmod 600 "$SHARED"/staging/ca/ca_key "$SHARED"/prod/ca/ca_key

echo "==> environments CA setup complete (staging, prod)"
echo "==> no user certificates issued yet - see issue.sh"

touch "$SHARED/.ready"
