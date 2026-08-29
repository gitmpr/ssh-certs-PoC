# ssh-certs-PoC — Chapter 5: GSSAPI (Kerberos)

> Continues from [**4_environment_cas**](https://github.com/gitmpr/ssh-certs-PoC/tree/4_environment_cas) and everything before it. All prior chapters are assumed knowledge here.

Every chapter so far has been a variation on one idea: a CA signs
something, and that signature can be checked completely offline. This
chapter steps outside that idea entirely, for contrast. GSSAPI - in
practice, almost always Kerberos - solves the same underlying problem
("nobody wants a long-lived secret sitting on every host") with a
structurally different mechanism: a **centrally trusted, always-reachable
KDC** issuing short-lived tickets, instead of a CA that can go offline the
moment it's done signing.

## GSSAPI/Kerberos SSH auth

`gssapi/` is a fourth, self-contained stack: a KDC, one host (`web01`,
GSSAPI-only - `PubkeyAuthentication`/`PasswordAuthentication` are both
off), and a client.

```sh
./scripts/gssapi-demo.sh
```

It tries `alice@web01` with no ticket (denied), runs `kinit` to get one
(a password prompt, piped non-interactively), connects successfully - no
key, no certificate involved anywhere - destroys the ticket with
`kdestroy`, and shows the connection denied again. See
[docs/gssapi.md](docs/gssapi.md) for the command reference and a
head-to-head comparison table against every certificate chapter.

**Worth being explicit about**: this chapter uses **Debian**, not Alpine
like everywhere else in this repo. Verified directly before building
anything: Alpine's `openssh-server` has no GSSAPI support compiled in at
all (`sshd -t` rejects `GSSAPIAuthentication` outright as an "Unsupported
option"); Debian's does. Also unlike every other stack here, the KDC is a
**long-running service**, not a one-shot setup container - Kerberos needs
its issuer reachable at connection time, which is the single biggest
structural difference from the certificate model.

## New in this chapter

```
gssapi/                 KDC + GSSAPI-only host + client, its own docker-compose.yml
  krb5.conf              shared Kerberos client config (realm SSHCERTS.LOCAL)
  kdc/                   long-running krb5kdc; mints alice's password-based
                          principal and web01's keytab-based host principal
  web01/                 Debian sshd, GSSAPI-only, no pubkey/password auth at all
  client/                Debian + krb5-user + openssh-client
scripts/gssapi-demo.sh  guided walkthrough (run from the host machine)
docs/gssapi.md           kinit/klist/kdestroy/ktadd reference + comparison table
```

## Chapters

This repo uses branches as chapters, each one building on the last:

| Chapter | Branch | Adds |
|---|---|---|
| 0 | [main](https://github.com/gitmpr/ssh-certs-PoC/tree/main) | CA, host certificates, user certificates, principals |
| 1 | [1_raw_keys](https://github.com/gitmpr/ssh-certs-PoC/tree/1_raw_keys) | Raw-keys comparison stack (no CA) - the "old way," right after the concept |
| 2 | [2_revocation](https://github.com/gitmpr/ssh-certs-PoC/tree/2_revocation) | Key revocation lists |
| 3 | [3_short-lived_secrets](https://github.com/gitmpr/ssh-certs-PoC/tree/3_short-lived_secrets) | On-demand, short-lived certificate issuance (single CA) |
| 4 | [4_environment_cas](https://github.com/gitmpr/ssh-certs-PoC/tree/4_environment_cas) | Separate CA per environment, plus a root/intermediate signing-key hierarchy |
| 5 | [5_gssapi](https://github.com/gitmpr/ssh-certs-PoC/tree/5_gssapi) (this branch) | GSSAPI/Kerberos SSH auth - a non-certificate trust model |

This is the newest chapter - the book ends here, for now.

## Further Reading & Resources

- [docs/validation.md](docs/validation.md) - exactly how the client
  validates the server and the server validates the client, in protocol
  order (chapter 0).
- [docs/cheatsheet.md](docs/cheatsheet.md) - every `ssh-keygen` flag used
  across the certificate chapters, explained.
- [docs/comparison.md](docs/comparison.md) - certificates vs. raw keys,
  failure mode by failure mode (chapter 1).
- [docs/gssapi.md](docs/gssapi.md) - the Kerberos/GSSAPI command
  reference and comparison table (this chapter).
- [docs/production.md](docs/production.md) - what's simplified across
  this whole repo, and what real-world CA setups (step-ca, Vault,
  Teleport, BLESS) do instead.
- ["If You're Not Using SSH Certificates You're Doing SSH Wrong"](https://www.youtube.com/watch?v=P-Yq_6Da1b8) -
  Mike Malone, BSidesSF 2020. The talk this whole repo is, in spirit, an
  extended illustration of.
- [The companion blog post](https://smallstep.com/blog/use-ssh-certificates/) -
  same title and author, Smallstep. Covers the same argument in text,
  plus a walkthrough of `step-ca`/`step ssh`.
- [OpenSSH `ssh-keygen(1)`](https://man.openbsd.org/ssh-keygen.1) - the
  `CERTIFICATES` section is the primary source for chapters 0-4.
- [MIT Kerberos documentation](https://web.mit.edu/kerberos/krb5-latest/doc/)
  - the primary source for this chapter.

## Scope

This is a private, educational proof of concept. Keys, certificates, and
Kerberos realms are generated fresh on every `docker compose up`, live
only in local Docker volumes, and are not meant to protect anything real.
