FROM alpine:3.20

RUN apk add --no-cache openssh-client

COPY entrypoint.sh /entrypoint.sh
COPY demo.sh /usr/local/bin/demo.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/demo.sh

ENTRYPOINT ["/entrypoint.sh"]
