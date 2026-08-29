# Debian, not Alpine like every other host in this repo - a deliberate,
# documented deviation. Alpine's openssh-server has no GSSAPI support
# compiled in at all (verified: sshd -t rejects GSSAPIAuthentication as
# "Unsupported option"); Debian's does. See the README for why this
# matters and docs/gssapi.md for the verification.
FROM debian:12-slim

RUN apt-get update -qq \
    && apt-get install -y -qq --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd \
    && useradd -m -s /bin/bash alice

COPY krb5.conf /etc/krb5.conf
COPY web01/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
