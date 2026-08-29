FROM alpine:3.20

RUN apk add --no-cache openssh-keygen

COPY entrypoint.sh /entrypoint.sh
COPY revoke.sh /usr/local/bin/revoke.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/revoke.sh

ENTRYPOINT ["/entrypoint.sh"]
