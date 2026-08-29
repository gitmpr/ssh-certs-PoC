#!/bin/sh
# The root CA. Runs once, mints a root key pair and, for each environment,
# the INTERMEDIATE CA key pair that environment's ca/ service will use for
# all its day-to-day host/user certificate signing (see ../ca/entrypoint.sh,
# which now waits for this to finish and consumes what's minted here
# instead of generating its own CA key). Then exits and is never involved
# again - "root stays cold, intermediates do the daily signing."
#
# IMPORTANT, and worth being precise about: SSH has no X.509-style
# certificate chain validation. TrustedUserCAKeys and @cert-authority only
# ever list flat, directly-trusted public keys - sshd/ssh never walks a
# chain up to some root it trusts. So this script also signs a
# "delegation certificate" over each intermediate's public key
# (ca_key-cert.pub, right next to ca_key.pub) as an AUDIT record - proof
# that root, at some point, approved this specific intermediate key - not
# as something any SSH software checks automatically. Nothing here makes
# root's approval enforced; it makes it verifiable. See
# scripts/environment-cas-demo.sh for what that verification actually
# looks like, and docs/production.md for the real-world equivalent (a
# host CA and a user CA, root CAs kept offline in an HSM, etc).

set -eu

SHARED=/shared
ROOT_DIR="$SHARED/root/ca"
mkdir -p "$ROOT_DIR"

# `docker compose run --rm ca ...` (see ../ca/issue.sh) re-checks this
# service's dependency condition on every single invocation - it doesn't
# remember that root-ca already completed successfully once. Without this
# guard, root would "come back online" and re-touch every file (including
# re-signing delegation certs) on every certificate request, which is
# exactly the operational pattern this chapter argues against. So: if
# root already minted everything, do nothing at all, instantly.
if [ -f "$SHARED/root/.ready" ]; then
    echo "==> root CA already minted its intermediates - nothing to do, staying cold"
    exit 0
fi

echo "==> root CA key pair"
if [ ! -f "$ROOT_DIR/root_key" ]; then
    ssh-keygen -t ed25519 -f "$ROOT_DIR/root_key" -C "ssh-certs-poc root CA" -N ""
fi

for env in staging prod; do
    ca_dir="$SHARED/$env/ca"
    mkdir -p "$ca_dir"

    echo "==> [$env] intermediate CA key pair (minted by root)"
    if [ ! -f "$ca_dir/ca_key" ]; then
        ssh-keygen -t ed25519 -f "$ca_dir/ca_key" -C "ssh-certs-poc $env intermediate CA" -N ""
    fi

    echo "==> [$env] root delegation certificate over the intermediate's public key"
    ssh-keygen -s "$ROOT_DIR/root_key" \
        -I "root_delegates_${env}_ca" \
        -h \
        -n "${env}-ca" \
        -V +52w \
        "$ca_dir/ca_key.pub"
    # ssh-keygen names the output "<file-minus-.pub>-cert.pub", so this
    # produces ca_key-cert.pub right next to ca_key.pub and ca_key
    # (the intermediate's own private key) - three files, one directory,
    # each with a distinct role: private key, public key, and now root's
    # signed statement about the public key.
done

chmod -R a+rX "$SHARED"
chmod 600 "$ROOT_DIR/root_key" "$SHARED"/staging/ca/ca_key "$SHARED"/prod/ca/ca_key

echo "==> root CA setup complete. Delegation certificates issued:"
for cert in "$SHARED"/*/ca/ca_key-cert.pub; do
    echo "----------------------------------------------------------------"
    ssh-keygen -Lf "$cert"
done

echo "==> root key will not be used again in this demo"
touch "$SHARED/root/.ready"
