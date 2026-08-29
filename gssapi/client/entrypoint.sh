#!/bin/sh
set -eu

SHARED=/shared

echo "==> waiting for KDC realm setup"
until [ -f "$SHARED/.ready" ]; do
    sleep 1
done

# Host identity isn't this chapter's concept - chapters 0-4 already cover
# host certificate validation in depth. Auto-accept-new here so a bare
# TOFU prompt (which can't be answered non-interactively anyway) doesn't
# get in the way of what this chapter actually demonstrates.
cat >> /etc/ssh/ssh_config <<'EOF'

Host *
    StrictHostKeyChecking accept-new
EOF

cat <<'EOF'
==> client ready

Nothing is authenticated yet - no ticket, nothing works:
    ssh alice@web01                 # denied, no credentials

Get a ticket, then it works:
    kinit alice                     # password: alicepassword
    klist                           # see what you got
    ssh alice@web01                 # succeeds via GSSAPI - no key, no cert

Destroy it, and it stops working again:
    kdestroy
    ssh alice@web01                 # denied again

See scripts/gssapi-demo.sh for the guided walkthrough.
EOF

exec tail -f /dev/null
