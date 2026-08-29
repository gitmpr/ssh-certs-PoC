FROM alpine:3.20

RUN apk add --no-cache openssh-server \
    && adduser -D -s /bin/sh ops && passwd -u ops \
    && adduser -D -s /bin/sh dba && passwd -u dba

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
