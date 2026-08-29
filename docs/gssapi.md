# GSSAPI/Kerberos cheatsheet

Reference for the commands and concepts used in this chapter. Mirrors
[cheatsheet.md](cheatsheet.md)'s role for the certificate chapters, for
an entirely different mechanism.

## The shape of it

- A **KDC** (Key Distribution Center) holds every principal's secret and
  issues tickets. It has to be reachable *at connection time*, not just
  at setup time - the core structural difference from the certificate
  chapters, where the CA can be completely offline once a certificate is
  issued.
- A **principal** is a Kerberos identity: `alice@REALM` for a person,
  `host/web01@REALM` for a service. The `/` instance qualifier is what
  distinguishes "alice, a human" from "the web01 service."
- Humans authenticate to the KDC with a **password** (`kinit`); services
  authenticate with a **keytab** - a file holding the service's own long-
  term key, so it never needs a human to type anything at login.
- A **ticket** (specifically a TGT, Ticket-Granting Ticket, from `kinit`)
  is the disposable credential - the equivalent role a short-lived
  certificate plays in chapters 3-4, except it lives in the KDC's realm,
  not signed by something you could verify offline.

## Commands

```sh
kinit alice           # get a TGT for alice@REALM, prompts for a password
klist                 # show what's currently in the ticket cache
kdestroy              # wipe the ticket cache
kvno host/web01       # check the current key version number of a principal
```

On the KDC only (uses the database file directly, no running daemon
needed):
```sh
kadmin.local -q "addprinc -pw <password> alice@REALM"       # human principal
kadmin.local -q "addprinc -randkey host/web01@REALM"         # service principal
kadmin.local -q "ktadd -k /path/web01.keytab host/web01@REALM"   # export its keytab
```

## sshd/ssh configuration

On the **host**:
```
# /etc/ssh/sshd_config
GSSAPIAuthentication yes
GSSAPICleanupCredentials yes
GSSAPIStrictAcceptorCheck no
```
`GSSAPIStrictAcceptorCheck no` relaxes hostname-to-principal matching -
useful here because container networking has no real reverse DNS for
Kerberos's usual FQDN-based principal matching to rely on. In a
DNS-complete environment you'd generally leave this at its default (yes).

On the **client**, to force the mechanism explicitly (useful for
demonstrating it's really GSSAPI doing the work, not something else):
```sh
ssh -o PreferredAuthentications=gssapi-with-mic alice@web01
```

## Feasibility note: this chapter uses Debian, not Alpine

Every other chapter in this repo uses Alpine. This one doesn't, because
Alpine's `openssh-server` has no GSSAPI support compiled in at all -
verified directly rather than assumed:

```sh
$ apk add openssh-server && sshd -t -f /tmp/test_config   # config sets GSSAPIAuthentication yes
Unsupported option GSSAPIAuthentication
```

Debian's build accepts the same directive cleanly. See the README for
the fuller story.

## Comparison to certificates

| | Certificates (chapters 0-4) | GSSAPI (this chapter) |
|---|---|---|
| What you hold locally | A long-lived key pair + a disposable certificate | Nothing - a ticket lives in a cache, obtained fresh each session |
| What proves your identity | A signature the CA can be verified against, offline | A ticket the KDC issued, which the KDC itself vouches for |
| Is the issuer needed at connection time? | No - a certificate is self-contained once issued | Yes - hosts and clients both need to reach the KDC live |
| Revocation | A KRL (chapter 2), or just let it expire (chapter 3) | Destroy the ticket (`kdestroy`), or let it expire - but the KDC could also just refuse to issue new ones |
