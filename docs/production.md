# From PoC to production

This repo simplifies things a working system would not. Worth being
explicit about what's cut, and what real systems do instead.

## What's simplified here

| Here | In production |
|---|---|
| CA private key lives in a container, generated on `docker compose up` | CA key lives offline, in an HSM, or behind a signing API that never exposes the key itself |
| Certificates issued once, up front | Issued on demand, per session, by a signing service in front of the CA |
| 8 hour user cert validity, chosen once | Often much shorter (minutes), reissued transparently as part of login |
| Two static principals (`ops`, `dba`) | Principals typically minted from an identity provider (SSO group membership, IAM role, etc.) at issuance time |
| No revocation list wired up | `RevokedKeys` (KRL) pushed by config management, or short-lived certs used specifically so revocation is rarely needed |
| One CA signs both hosts and users | Often two separate CAs (a host CA and a user CA), so compromising one doesn't grant the other's trust |

## Real signing services

- **[step-ca](https://smallstep.com/docs/step-ca/)** (Smallstep) - open
  source CA with an SSH mode; issues short-lived certs via `step ssh certificate`,
  integrates with OIDC for identity.
- **[HashiCorp Vault SSH secrets engine](https://developer.hashicorp.com/vault/docs/secrets/ssh)** -
  Vault holds the CA key, issues certs via API/CLI, ties into Vault's
  existing auth methods and audit logging.
- **[Teleport](https://goteleport.com/)** - goes further than "just" SSH
  certs: session recording, RBAC, short-lived certs tied to SSO, a proxy
  that brokers every connection.
- **[Netflix BLESS](https://github.com/Netflix-Skunkworks/bless)** - AWS
  Lambda-based CA; certs are minted on demand, valid for minutes, so there
  is effectively nothing long-lived to revoke.

## Why short-lived certificates matter

A raw key in `authorized_keys` is valid until someone notices it shouldn't
be and deletes it - which, in practice, is close to "forever". A
certificate with a short `-V` window is only ever a liability for as long
as that window, and then it simply stops working, no cleanup required.
Pushed far enough (minutes), you get most of the benefit of revocation
without needing a revocation mechanism at all - the failure mode of "we
forgot to revoke this" stops being possible.

## Host CA vs user CA

This repo uses a single CA key for both host and user certificates,
because one trust anchor is simpler to visualize. In production it is
common to split them:

```
HostKey            /etc/ssh/ssh_host_ed25519_key
HostCertificate     /etc/ssh/ssh_host_ed25519_key-cert.pub   # signed by host CA
TrustedUserCAKeys   /etc/ssh/user_ca.pub                     # trusts user CA
```

That way, a compromise of the host-issuing pipeline cannot be used to mint
credentials that let someone *log in* anywhere, and vice versa.
