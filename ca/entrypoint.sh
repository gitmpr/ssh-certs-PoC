#!/bin/sh
# The Certificate Authority.
#
# A CA in the SSH sense is nothing but a regular SSH key pair whose *public*
# half everyone agrees to trust, plus the discipline of using its *private*
# half only to sign other people's public keys. There is no separate PKI
# software involved - ssh-keygen does everything.
#
# This script:
#   1. creates the CA key pair (once)
#   2. creates a host key pair per host and signs it into a host certificate
#   3. creates a user key pair per demo user and signs it into a user
#      certificate, tagged with a "principal" (role) rather than a hostname
#
# In production the CA private key would live offline, in an HSM, or behind
# a signing service (Vault SSH secrets engine, step-ca, Teleport, netflix
# BLESS, ...) instead of sitting in a container. See docs/production.md.

set -eu

SHARED=/shared
CA_DIR="$SHARED/ca"
HOSTS_DIR="$SHARED/hosts"
USERS_DIR="$SHARED/users"

mkdir -p "$CA_DIR" "$HOSTS_DIR" "$USERS_DIR"

echo "==> [1/3] CA key pair"
if [ ! -f "$CA_DIR/ca_key" ]; then
    ssh-keygen -t ed25519 -f "$CA_DIR/ca_key" -C "ssh-certs-poc CA" -N ""
else
    echo "    already exists, reusing"
fi

# sign_host <hostname>
#
# Creates a host key pair (if missing) and signs it into a host certificate
# whose only valid principal is <hostname>. A client that trusts this CA for
# host certificates will accept this host under that name, with no manual
# known_hosts entry required.
sign_host() {
    name="$1"
    dir="$HOSTS_DIR/$name"
    mkdir -p "$dir"

    if [ ! -f "$dir/ssh_host_ed25519_key" ]; then
        ssh-keygen -t ed25519 -f "$dir/ssh_host_ed25519_key" -C "$name" -N ""
    fi

    echo "==> [2/3] host certificate for $name (principal: $name)"
    ssh-keygen -s "$CA_DIR/ca_key" \
        -I "host_${name}" \
        -h \
        -n "$name" \
        -V +52w \
        "$dir/ssh_host_ed25519_key.pub"
}

# sign_user <username> <principal>
#
# Creates a user key pair (if missing) and signs it into a user certificate
# carrying <principal> - a role, not necessarily the username. A host that
# trusts this CA for user certificates decides per-account which principals
# it will accept (see hosts/entrypoint.sh AuthorizedPrincipalsFile). That
# indirection is what makes certificates a role-based access control
# mechanism instead of just "a key that doesn't need copying around".
sign_user() {
    user="$1"
    principal="$2"
    dir="$USERS_DIR/$user"
    mkdir -p "$dir"

    if [ ! -f "$dir/id_ed25519" ]; then
        ssh-keygen -t ed25519 -f "$dir/id_ed25519" -C "$user" -N ""
    fi

    echo "==> [3/3] user certificate for $user (principal: $principal)"
    # Short validity on purpose: certificates expire by design, unlike bare
    # keys dropped into authorized_keys, which are valid forever until
    # someone remembers to remove them.
    ssh-keygen -s "$CA_DIR/ca_key" \
        -I "user_${user}" \
        -n "$principal" \
        -V +8h \
        "$dir/id_ed25519.pub"
}

sign_host web01
sign_host db01

sign_user alice ops
sign_user carol dba

# Everything under $SHARED needs to be readable by the other containers.
chmod -R a+rX "$SHARED"
chmod 600 "$CA_DIR/ca_key"

echo "==> CA setup complete. Issued certificates:"
for cert in "$HOSTS_DIR"/*/*-cert.pub "$USERS_DIR"/*/*-cert.pub; do
    echo "----------------------------------------------------------------"
    ssh-keygen -Lf "$cert"
done

# Signals to everyone else that certificates exist.
touch "$SHARED/.ready"
