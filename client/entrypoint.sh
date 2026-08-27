#!/bin/sh
# The client only needs one thing to skip host-key verification prompts for
# every current and future host signed by our CA: a `@cert-authority` line
# naming the CA's public key. That line goes into the *global* known_hosts
# file so it applies to every user certificate we try below, without ever
# touching each host individually.

set -eu

SHARED=/shared

echo "==> waiting for CA material"
until [ -f "$SHARED/.ready" ]; do
    sleep 1
done

mkdir -p /root/.ssh
chmod 700 /root/.ssh

echo "@cert-authority * $(cat "$SHARED/ca/ca_key.pub")" > /etc/ssh/ssh_known_hosts

# ssh automatically looks for "<identity>-cert.pub" next to an identity file
# passed via -i, so keeping that naming lets `-i /root/.ssh/alice` pick up
# the certificate with no extra flags.
cp "$SHARED/users/alice/id_ed25519"          /root/.ssh/alice
cp "$SHARED/users/alice/id_ed25519-cert.pub" /root/.ssh/alice-cert.pub
cp "$SHARED/users/carol/id_ed25519"          /root/.ssh/carol
cp "$SHARED/users/carol/id_ed25519-cert.pub" /root/.ssh/carol-cert.pub
chmod 600 /root/.ssh/alice /root/.ssh/carol
chmod 644 /root/.ssh/alice-cert.pub /root/.ssh/carol-cert.pub

cat <<'EOF'
==> client ready

Run the guided walkthrough:
    demo.sh

Or try it by hand, e.g.:
    ssh -i /root/.ssh/alice ops@web01
    ssh -i /root/.ssh/carol dba@db01
    ssh -i /root/.ssh/alice dba@db01   # wrong principal -> denied

Inspect a certificate:
    ssh-keygen -Lf /root/.ssh/alice-cert.pub
EOF

exec tail -f /dev/null
