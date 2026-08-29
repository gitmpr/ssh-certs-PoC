# From PoC to production

This repo simplifies things a working system would not. Worth being
explicit about what's cut, and what real systems do instead.

## What earlier chapters simplified, and what addresses it

| Simplified in `main` | Addressed in |
|---|---|
| Certificates issued once, up front, with a long fixed validity | [`3_short-lived_secrets`](https://github.com/gitmpr/ssh-certs-PoC/tree/3_short-lived_secrets) - `ca/issue.sh` issues on demand, short-lived. alice/carol still get the original pre-issued 8h certs, deliberately left alone, for contrast. |
| Revocation is a manual `revoke.sh <user>` call | [`2_revocation`](https://github.com/gitmpr/ssh-certs-PoC/tree/2_revocation) - see `ca/revoke.sh` and `scripts/revoke-demo.sh` |
| One CA for everything, no environment separation | This chapter's `environments/` stack - a separate intermediate CA per environment (staging, prod), both minted and delegated to by a root CA that then goes cold. See `scripts/environment-cas-demo.sh`. |

## What's still simplified here

| Here | In production |
|---|---|
| Root CA private key lives in a container, generated on `docker compose up` | Root CA key lives offline, in an HSM, or behind a signing API that never exposes the key itself |
| Two static principals (`ops`, `dba`) | Principals typically minted from an identity provider (SSO group membership, IAM role, etc.) at issuance time |
| Each environment's intermediate CA signs both hosts and users | Often split further into a host CA and a user CA per environment - see "Host CA vs user CA" below |
| The client reaches every host directly | Real fleets are usually reached through a bastion/jump host - see below |

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

Every CA in this repo - the single CA in chapters 0-3, and each
environment's intermediate CA in chapter 4 - signs both host and user
certificates, because one trust anchor per environment is simpler to
visualize. In production it is common to split further, per environment:

```
HostKey            /etc/ssh/ssh_host_ed25519_key
HostCertificate     /etc/ssh/ssh_host_ed25519_key-cert.pub   # signed by host CA
TrustedUserCAKeys   /etc/ssh/user_ca.pub                     # trusts user CA
```

That way, a compromise of the host-issuing pipeline cannot be used to mint
credentials that let someone *log in* anywhere, and vice versa. Chapter
4's root/intermediate pattern composes with this cleanly: a root CA could
just as easily mint four intermediates (host + user, per environment)
instead of two.

## Bastion and jump hosts (not built here)

Every stack in this repo has the client reach each host directly. Real
fleets are usually reached through one or more bastion hosts instead - the
client only ever talks to the bastion, which then relays the connection
onward. Certificates compose cleanly with this, which is worth knowing
even without a running example:

- `ssh -J bastion ops@web01` (or `ProxyJump bastion` in `ssh_config`)
  presents the *same* user certificate at both hops - the bastion and the
  destination host each independently check it against their own
  `TrustedUserCAKeys`/`AuthorizedPrincipalsFile`, so access to the bastion
  doesn't imply access to what's behind it.
- This avoids the classic alternative, agent forwarding through the
  bastion, which hands the bastion the ability to *use* your key (via your
  running agent) for as long as you're connected - a much bigger blast
  radius if the bastion is compromised mid-session.
- Nothing about the CA setup changes: the bastion is just another host
  with a host certificate and `TrustedUserCAKeys`, like `web01` or
  `staging-web01` here.

Not built as a stack in this repo because it doesn't add a new trust
mechanism to illustrate - it's the same host-cert/user-cert validation
from [docs/validation.md](validation.md), one hop further along.
