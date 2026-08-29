# ssh-certs-PoC — Chapter 3: On-Demand, Short-Lived Secrets

> Continues from [**2_revocation**](https://github.com/gitmpr/ssh-certs-PoC/tree/2_revocation) and, before that, [**1_raw_keys**](https://github.com/gitmpr/ssh-certs-PoC/tree/1_raw_keys) and [**main**](https://github.com/gitmpr/ssh-certs-PoC/tree/main). All three are assumed knowledge here.

Chapter 2 killed a certificate on demand. This chapter asks the other
half of the same lifecycle question: what if you never had to? A
certificate with a short enough validity window expires before anyone
needs to remember to revoke it.

## On-demand, short-lived issuance

`ca/issue.sh` mints a fresh, short-lived certificate on request, against
the *same single CA* chapter 0 already set up - no new stack, no new
hosts:

```sh
docker compose up --build -d   # chapter 0 stack must already be running
./scripts/short-lived-demo.sh
```

It issues a 2-minute certificate for a brand-new identity, `dan`
(principal `ops` - reusing `web01`), connects successfully, and then -
genuinely, by sleeping through it rather than asserting it - waits for
the certificate's validity window to run out and shows it stop working
with no revocation step involved at all. Runs a little over two minutes
end to end.

`dan` never touches alice or carol's already-tested, pre-issued
certificates from chapters 0-2 - `demo.sh` and `revoke-demo.sh` keep
working completely unmodified. See
[docs/production.md](docs/production.md) for how real signing services
(step-ca, Vault, ...) turn this into something nobody has to think about
- certificates minted transparently, every login, for minutes at a time.

## New in this chapter

```
ca/issue.sh                  mint a short-lived user certificate on demand
ca/Dockerfile                (updated) ships issue.sh alongside revoke.sh
scripts/short-lived-demo.sh  guided on-demand issuance walkthrough
docs/production.md           (updated) issuance/validity rows now point here
```

## Chapters

This repo uses branches as chapters, each one building on the last:

| Chapter | Branch | Adds |
|---|---|---|
| 0 | [main](https://github.com/gitmpr/ssh-certs-PoC/tree/main) | CA, host certificates, user certificates, principals |
| 1 | [1_raw_keys](https://github.com/gitmpr/ssh-certs-PoC/tree/1_raw_keys) | Raw-keys comparison stack (no CA) - the "old way," right after the concept |
| 2 | [2_revocation](https://github.com/gitmpr/ssh-certs-PoC/tree/2_revocation) | Key revocation lists |
| 3 | [3_short-lived_secrets](https://github.com/gitmpr/ssh-certs-PoC/tree/3_short-lived_secrets) (this branch) | On-demand, short-lived certificate issuance (single CA) |
| 4 | [4_environment_cas](https://github.com/gitmpr/ssh-certs-PoC/tree/4_environment_cas) | Separate CA per environment, plus a root/intermediate signing-key hierarchy |
| 5 | [5_gssapi](https://github.com/gitmpr/ssh-certs-PoC/tree/5_gssapi) | GSSAPI/Kerberos SSH auth - a non-certificate trust model. Ends with Further Reading & Resources. |

up next: [**4_environment_cas**](https://github.com/gitmpr/ssh-certs-PoC/tree/4_environment_cas)
