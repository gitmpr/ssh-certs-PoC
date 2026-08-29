#!/bin/sh
# Guided walkthrough for per-environment CA isolation and the root/
# intermediate signing-key hierarchy above it. Run from the repo root, on
# the machine running docker compose (not inside a container) - same
# reasoning as scripts/revoke-demo.sh.
#
#   ./scripts/environment-cas-demo.sh
#
# Brings the environments/ stack up itself. Does not `set -e`: one step is
# supposed to fail, and the point is to see and explain why.
#
# On-demand issuance (ca/issue.sh, the TTL below) is chapter 3's concept,
# reused here rather than re-explained - this chapter's new material is
# the CA topology: two intermediates, one root, and the fact that sshd
# never validates that hierarchy for you.

set -u
cd "$(dirname "$0")/.."

COMPOSE="docker compose -f environments/docker-compose.yml"
SSH="ssh -o ConnectTimeout=5"
KEY=/shared/users/alice/id_ed25519
STAGING_CERT=/shared/users/alice/id_ed25519.staging-cert.pub
PROD_CERT=/shared/users/alice/id_ed25519.prod-cert.pub
TTL=10m

section() {
    echo
    echo "############################################################"
    echo "# $1"
    echo "############################################################"
}

section "0. bring the environments stack up"
$COMPOSE up --build -d
sleep 2

section "1. request a staging certificate for alice (reusing chapter 3's issue.sh)"
echo "\$ issue.sh staging alice ops $TTL"
$COMPOSE run --rm --entrypoint /usr/local/bin/issue.sh ca staging alice ops "$TTL"

section "2. alice -> staging-web01 [expect: SUCCESS]"
echo "\$ ssh -o CertificateFile=...staging-cert.pub -i alice-key ops@staging-web01"
$COMPOSE exec client $SSH -o CertificateFile=$STAGING_CERT -i $KEY \
    ops@staging-web01 'echo "  -> logged in to $(hostname) as $(whoami)"'

section "3. the SAME staging certificate, against prod-web01 [expect: DENIED]"
echo "\$ ssh -o CertificateFile=...staging-cert.pub -i alice-key ops@prod-web01"
$COMPOSE exec client $SSH -o CertificateFile=$STAGING_CERT -i $KEY \
    ops@prod-web01 'echo should not print'
echo "  -> denied. Nothing wrong with the certificate: CA-signed, unexpired,"
echo "     principal 'ops' matches the local account, same as step 2. But"
echo "     prod-web01's TrustedUserCAKeys only names the PROD intermediate"
echo "     CA - a certificate from a different environment's CA isn't a"
echo "     policy violation here, it's simply unsigned as far as this host"
echo "     is concerned. See environments/hosts/entrypoint.sh."

section "4. request a prod certificate too - same underlying key pair"
echo "\$ issue.sh prod alice ops $TTL"
$COMPOSE run --rm --entrypoint /usr/local/bin/issue.sh ca prod alice ops "$TTL"
echo "\$ ssh -o CertificateFile=...prod-cert.pub -i alice-key ops@prod-web01"
$COMPOSE exec client $SSH -o CertificateFile=$PROD_CERT -i $KEY \
    ops@prod-web01 'echo "  -> logged in to $(hostname) as $(whoami)"'
echo "  -> alice's key pair never changed - only the certificate wrapping"
echo "     it did. Compare the 'Public key:' line on both certificates:"
$COMPOSE exec client sh -c "ssh-keygen -Lf $STAGING_CERT | grep 'Public key'"
$COMPOSE exec client sh -c "ssh-keygen -Lf $PROD_CERT | grep 'Public key'"

section "5. where did staging's and prod's intermediate CAs come from?"
echo "Neither environment generated its own CA key - root-ca/ minted both"
echo "and signed a delegation certificate over each intermediate's public"
echo "key before going cold. sshd never checks this chain (SSH has no"
echo "concept of one); it's an audit record, verified here by hand:"
echo
echo "\$ ssh-keygen -Lf /shared/staging/ca/ca_key-cert.pub"
$COMPOSE exec client ssh-keygen -Lf /shared/staging/ca/ca_key-cert.pub
ROOT_FP=$($COMPOSE exec -T client ssh-keygen -lf /shared/root/ca/root_key.pub | awk '{print $2}')
CERT_CA_FP=$($COMPOSE exec -T client sh -c \
    "ssh-keygen -Lf /shared/staging/ca/ca_key-cert.pub | grep 'Signing CA' | grep -oE 'SHA256:[^ ]+'")
echo
echo "root_key.pub fingerprint:            $ROOT_FP"
echo "staging delegation cert's Signing CA: $CERT_CA_FP"
if [ "$ROOT_FP" = "$CERT_CA_FP" ]; then
    echo "  -> match. This delegation certificate was genuinely signed by"
    echo "     root, not forged or self-issued by the staging intermediate."
else
    echo "  -> MISMATCH - something is wrong, this should never happen" >&2
    exit 1
fi

echo
echo "Done. See docs/production.md for the real-world equivalent of this"
echo "hierarchy (offline root CAs, host CA vs. user CA, HSMs)."
echo "Tear down: docker compose -f environments/docker-compose.yml down -v"
