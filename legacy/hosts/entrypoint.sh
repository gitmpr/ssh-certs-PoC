#!/bin/sh
# Classic key-based sshd: no CA, no certificates. Everything here is
# exactly the pre-certificate model the main stack's README argues against.
#
#   Host identity: ssh-keygen -A generates this host's key pair the first
#   time it's needed. There is nothing that pins it across a rebuild - a
#   fresh container (docker compose up --force-recreate) gets a brand new
#   identity, and every client that already trusted the old one is stuck
#   with a mismatch until someone fixes their known_hosts by hand.
#
#   User authorization: each local account's ~/.ssh/authorized_keys starts
#   empty. Granting someone access means appending their public key here,
#   on this specific host - see scripts/legacy-demo.sh. There is no
#   central "who can log in as ops anywhere" list; the only record of who
#   was ever granted access is scattered across every host's
#   authorized_keys file.

set -eu

ssh-keygen -A

for u in ops dba; do
    home="/home/$u"
    mkdir -p "$home/.ssh"
    touch "$home/.ssh/authorized_keys"
    chown -R "$u:$u" "$home/.ssh"
    chmod 700 "$home/.ssh"
    chmod 600 "$home/.ssh/authorized_keys"
done

cat >> /etc/ssh/sshd_config <<EOF

# --- ssh-certs-PoC (legacy comparison) ---
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF

echo "==> $(hostname) ready (classic authorized_keys model), starting sshd"
exec /usr/sbin/sshd -D -e
