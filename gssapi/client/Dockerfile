FROM debian:12-slim

RUN apt-get update -qq \
    && apt-get install -y -qq --no-install-recommends openssh-client krb5-user \
    && rm -rf /var/lib/apt/lists/*

COPY krb5.conf /etc/krb5.conf
COPY client/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
