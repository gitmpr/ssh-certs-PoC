FROM alpine:3.20

RUN apk add --no-cache openssh-keygen

COPY entrypoint.sh /entrypoint.sh
COPY issue.sh /usr/local/bin/issue.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/issue.sh

ENTRYPOINT ["/entrypoint.sh"]
