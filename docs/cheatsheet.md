# ssh-keygen cheatsheet

Reference for the flags used throughout this repo. `ssh-keygen` is the only
tool involved anywhere - there is no separate "CA program".

## Generating keys

```sh
ssh-keygen -t ed25519 -f ./mykey -C "comment" -N ""
```
- `-t ed25519` - key type. Ed25519 throughout this repo: small keys, small
  certificates, fast, no parameter-choice footguns (compare RSA key sizes).
- `-f` - output file for the private key; the public key is `<file>.pub`.
- `-C` - comment, purely cosmetic.
- `-N ""` - empty passphrase (this is a disposable demo CA/keys).

## Signing a host certificate

```sh
ssh-keygen -s ca_key -I host_web01 -h -n web01 -V +52w ssh_host_ed25519_key.pub
```
- `-s ca_key` - sign with this CA private key.
- `-I host_web01` - "key ID", a free-text label. Shows up in sshd's auth
  logs, so make it identify what was signed and for whom/what.
- `-h` - **h**ost certificate (omit for a user certificate).
- `-n web01` - comma-separated list of valid principals. For a host
  certificate, this is the hostname(s) clients are allowed to reach it as.
- `-V +52w` - validity window, relative to signing time. Also accepts
  absolute timestamps and ranges (`-V 20260101:20270101`).

Produces `ssh_host_ed25519_key-cert.pub` alongside the public key.

## Signing a user certificate

```sh
ssh-keygen -s ca_key -I user_alice -n ops -V +8h id_ed25519.pub
```
- Same flags, minus `-h`. `-n ops` is the principal (role) this identity is
  allowed to assert - not necessarily the username.
- `-O` adds extensions/critical options, e.g.:
  - `-O force-command=/usr/local/bin/backup.sh` - only that command may run.
  - `-O source-address=10.0.0.0/8` - only from that network.
  - `-O no-port-forwarding,no-agent-forwarding,no-X11-forwarding` - trim
    what the certificate is allowed to do.

## Inspecting a certificate

```sh
ssh-keygen -Lf id_ed25519-cert.pub
```
Prints type, key ID, serial, valid principals, validity window, and any
critical options/extensions. This is the fastest way to answer "what does
this certificate actually let me do".

## Trusting a CA

On a **server**, to accept user certificates:
```
# /etc/ssh/sshd_config
TrustedUserCAKeys /etc/ssh/user_ca.pub
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
```

On a **client**, to accept host certificates:
```
echo "@cert-authority * $(cat ca_key.pub)" >> ~/.ssh/known_hosts
```
`*` can be narrowed to a hostname pattern, e.g. `*.internal.example.com`.

## Revocation (KRL)

Certificates expire on their own (`-V`), but if one needs to be killed
early - a laptop stolen, a role retired - use a Key Revocation List. This
repo wires one up for real; see `ca/revoke.sh` and
`scripts/revoke-demo.sh`.

Every certificate this repo issues has serial 0, so revocation is by key
ID (the `-I` string given at signing time, e.g. `user_carol`) rather than
by serial number:

```sh
# spec file: one "id:" or "serial:" line per identity to revoke
echo "id: user_carol" > spec

# first write: creates the KRL
ssh-keygen -k -f revoked.krl -s ca_key.pub -z 1 spec

# subsequent writes: -u updates the existing file, -z must increase
ssh-keygen -k -f revoked.krl -u -s ca_key.pub -z 2 spec
```

Test whether a given certificate is in a KRL:
```sh
ssh-keygen -Qf revoked.krl id_ed25519-cert.pub
```
Note the exit code is the opposite of what you'd guess: **0** ("ok") means
*not* revoked, **non-zero** ("REVOKED") means it is.

On each host:
```
# /etc/ssh/sshd_config
RevokedKeys /path/to/revoked.krl
```
sshd re-reads that file on every connection attempt, so if the path points
at something live (this repo points it straight at the shared volume - see
`hosts/entrypoint.sh`), revocation takes effect immediately, with no host
restart and no redistribution step.
