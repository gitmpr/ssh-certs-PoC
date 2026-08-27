# How validation actually happens

The README shows *what* gets trusted. This is *how* that trust gets checked,
in protocol order, and it answers a question that trips people up: does a
host certificate encode a DNS name? (No.)

Every SSH connection with certificates does two independent validations, in
two different protocol phases, in two different directions. Each one splits
into the same two questions:

1. **Possession** - does the far end actually hold the private key matching
   the public key in the certificate it just showed me? (pure cryptography,
   answered by a digital signature)
2. **Trust** - even if it does, *should* I accept that certificate for what
   it's being used for here? (policy, answered by CA trust + principal
   matching + validity window)

A certificate only ever proves who signed it and what it says. It cannot,
by itself, prove that the party presenting it is the one it was issued to -
that's what the possession check is for. The two checks are independent and
both have to pass.

## 1. Server -> client: host authentication

This happens during the SSH key exchange (KEX), before the connection has
any notion of *which user* is logging in - the server proves its identity
to an as-yet-anonymous client.

**Possession.** As part of the key exchange, the server sends its host
certificate and a signature, made with its host *private* key, over the
exchange hash (a value both sides derive from this specific handshake's
key-exchange material). The client recomputes that hash itself and verifies
the signature against the public key embedded in the certificate. If it
doesn't check out, the connection is aborted right there, before any trust
decision is even reached - this is a hard, protocol-level cryptographic
check, not a policy one.

Real output from this repo (`ssh -v`, trimmed):
```
debug1: Server host certificate: ssh-ed25519-cert-v01@openssh.com ...
  ID "host_web01" CA ssh-ed25519 SHA256:noSTM0... valid from ... to ...
debug1: Host 'web01' is known and matches the ED25519-CERT host certificate.
debug1: Found CA key in /etc/ssh/ssh_known_hosts:1
```
By the time that first line prints, the signature has already been verified
- ssh wouldn't describe the certificate's contents at all if the crypto had
failed.

**Trust.** Signature aside, the client still has to decide *should I accept
this*. It checks, in order:
- Is this certificate signed by a CA I trust for host certificates? (a
  `@cert-authority` line in `known_hosts` - see [`client/entrypoint.sh`](../client/entrypoint.sh))
- Is `now` inside the certificate's validity window?
- Does the certificate's principal list contain the name I'm trying to
  reach? This is the part covered below, under "does a certificate encode
  a hostname?" - short answer: not a DNS name, a string.

If a plain (non-certificate) host key were used instead, this is where
`known_hosts` TOFU and "the authenticity of host ... can't be established"
come from - the client has no CA to ask, so it falls back to "have I seen
this exact key before". Certificates skip that fallback entirely, which is
the "no TOFU prompt" behavior step 4 of `demo.sh` points out.

## 2. Client -> server: user authentication

This happens *after* the step above completes - the transport is already
encrypted and the server has already proven its identity. The client now
authenticates to that already-trusted server.

**Possession.** The client sends a `publickey` userauth request carrying
its certificate and a signature, made with its user *private* key, over a
blob that includes the session identifier from the key exchange in step 1.
That binding is deliberate: the signature is only valid for *this specific
connection*, so it can't be captured and replayed against a different
session or relayed on to a different server pretending to be a client. The
server verifies the signature against the public key embedded in the
certificate - same possession proof as before, opposite direction.

**Trust.** Again, independent of the crypto:
- Is this certificate signed by a CA I trust for user certificates?
  (`TrustedUserCAKeys` - see [`hosts/entrypoint.sh`](../hosts/entrypoint.sh))
- Is `now` inside the certificate's validity window?
- Does the certificate's principal list contain an entry authorized for
  *the specific local account being logged into*? (`AuthorizedPrincipalsFile`,
  looked up per target account via `%u`)
- Are any critical options satisfied (`force-command`, `source-address`,
  ...)? See [cheatsheet.md](cheatsheet.md).

This is exactly what step 3 of `demo.sh` demonstrates: alice's certificate
passes possession *and* CA trust *and* validity - and is still refused,
because db01's `AuthorizedPrincipalsFile` for account `dba` doesn't list
`ops`. A perfectly valid, perfectly genuine certificate is not the same
thing as an authorized one.

## Does a certificate specify a DNS name?

No. A host certificate's principal list (`-n` at signing time, see
[cheatsheet.md](cheatsheet.md)) is a set of arbitrary strings chosen by
whoever ran the CA - there is no DNS record, reverse lookup, or resolver
involved in validating them at all.

What actually gets compared, string-for-string, is whatever name/address
the client *used to try to reach the host* - literally the argument you
gave `ssh` (or the `Host`/`HostName` from `ssh_config`), unless overridden
by `HostKeyAlias`. How that string turns into a TCP connection - real DNS,
a `/etc/hosts` line, Docker's embedded DNS, a raw IP literal - is a
completely separate, earlier step that certificate validation neither
knows nor cares about.

Concretely, in this repo: `ssh ops@web01` uses Docker Compose's embedded
DNS to resolve `web01` to a container IP for routing. But `web01`'s host
certificate would validate identically if that same name came from a
static `/etc/hosts` entry, because principal matching only ever sees the
literal string `"web01"` - never the IP it resolved to, and never a DNS
answer.

That generalizes directly to your question:

- **A `/etc/hosts`-only network works exactly the same way.** Sign the
  host certificate's principal to match whatever name is in the managed
  `/etc/hosts` entry, and connect using that name. Nothing else changes.
- **You don't even need names at all.** You can sign a principal that is
  itself an IP literal (`-n 10.0.0.5`) and connect with `ssh user@10.0.0.5`
  directly - it's still just a string comparison.
- **`HostKeyAlias`** (an `ssh_config` option) lets you decouple "how I
  connect" from "what name gets checked against the certificate" - useful
  if you reach a host through a jump box, a load balancer, or several
  interchangeable addresses, and want certificate validation to check a
  single canonical name regardless of which address was actually dialed.
- One practical upside worth naming: because none of this touches DNS,
  there's no DNSSEC/DNS-spoofing angle to worry about in host validation -
  compare that to mechanisms like `SSHFP` DNS records, which explicitly do
  depend on DNS integrity.

## Summary

| | Server -> client (host auth) | Client -> server (user auth) |
|---|---|---|
| When | During key exchange, before any user identity | After transport is encrypted, during userauth |
| Possession proof | Server signs the KEX exchange hash with its host key | Client signs a blob bound to the session ID with its user key |
| Trust anchor | `@cert-authority` in `known_hosts` | `TrustedUserCAKeys` |
| Authorization scope | Certificate principal must match the connection target string | Certificate principal must be listed in `AuthorizedPrincipalsFile` for the target account |
| DNS involved? | No - string match only | N/A |
