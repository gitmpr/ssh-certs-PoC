FROM debian:12-slim

RUN apt-get update -qq \
    && apt-get install -y -qq --no-install-recommends krb5-kdc krb5-admin-server \
    && rm -rf /var/lib/apt/lists/*

COPY krb5.conf /etc/krb5.conf
COPY kdc/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
