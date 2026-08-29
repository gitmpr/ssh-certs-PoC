#!/bin/sh
# A plain ssh client: one static key pair, no CA trust of any kind. Every
# host it connects to has to be learned individually via known_hosts TOFU,
# and has to have this key pasted into its authorized_keys before login
# works at all.

set -eu

mkdir -p /root/.ssh
chmod 700 /root/.ssh

if [ ! -f /root/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -C "legacy-client" -N ""
fi

cat <<'EOF'
==> legacy client ready

Nothing is pre-authorized. This client's public key has to be pasted into
authorized_keys on each host before it can log in there - see
scripts/legacy-demo.sh for the guided walkthrough, or by hand:

    docker compose -f legacy/docker-compose.yml exec legacy-client \
        cat /root/.ssh/id_ed25519.pub
    docker compose -f legacy/docker-compose.yml exec legacy-web01 \
        sh -c 'cat >> /home/ops/.ssh/authorized_keys'
    docker compose -f legacy/docker-compose.yml exec legacy-client \
        ssh -o StrictHostKeyChecking=accept-new -i /root/.ssh/id_ed25519 ops@legacy-web01
EOF

exec tail -f /dev/null
