FROM alpine:3.20

RUN apk add --no-cache openssh-server openssh-keygen \
    # One local unix account per role. Note that having the account exist
    # does not by itself grant access - see entrypoint.sh: only the role
    # named in ALLOWED_PRINCIPAL gets an AuthorizedPrincipalsFile entry.
    # `adduser -D` leaves the account password-locked, which OpenSSH treats
    # as a disabled account regardless of auth method; `passwd -u` clears
    # that lock. PasswordAuthentication is disabled in sshd_config, so this
    # never opens up password login - only certificate login on an
    # unlocked account.
    && adduser -D -s /bin/sh ops && passwd -u ops \
    && adduser -D -s /bin/sh dba && passwd -u dba

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
