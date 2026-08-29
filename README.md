# ssh-certs-PoC — Chapter 2: Revocation

> Continues from [**1_raw_keys**](https://github.com/gitmpr/ssh-certs-PoC/tree/1_raw_keys) and, before that, [**main**](https://github.com/gitmpr/ssh-certs-PoC/tree/main). Both are assumed knowledge here.

A certificate being valid - CA-signed, right principal, unexpired -
doesn't mean it stays valid forever. This chapter wires up the one
lifecycle event chapter 0 didn't cover: killing a certificate on demand,
before its natural expiry.

## Revocation

`scripts/revoke-demo.sh` kills a certificate on demand, against chapter
0's stack:

```sh
docker compose up --build -d
./scripts/revoke-demo.sh
```

It revokes carol's certificate mid-demo and shows `db01` rejecting her on
the very next connection attempt - not because it expired (her `Valid:`
window is still open), but because `revoke.sh` updated a Key Revocation
List that every host reads live off the shared volume. No host restart, no
config redistribution, no per-host edit. Alice is unaffected: revocation
is per-identity, not a blunt instrument. See [`ca/revoke.sh`](ca/revoke.sh)
and [docs/cheatsheet.md](docs/cheatsheet.md#revocation-krl) for the
mechanics.

## New in this chapter

```
ca/revoke.sh              revoke a user certificate by key ID, updates the KRL
ca/entrypoint.sh          (updated) initializes an empty KRL at CA setup
hosts/entrypoint.sh       (updated) RevokedKeys now points at the live KRL
scripts/revoke-demo.sh    guided revocation walkthrough (run from the host machine)
docs/cheatsheet.md        (updated) revocation (KRL) section - a real, wired-up mechanism
docs/production.md        (updated) revocation row now points here
```

## Chapters

This repo uses branches as chapters, each one building on the last:

| Chapter | Branch | Adds |
|---|---|---|
| 0 | [main](https://github.com/gitmpr/ssh-certs-PoC/tree/main) | CA, host certificates, user certificates, principals |
| 1 | [1_raw_keys](https://github.com/gitmpr/ssh-certs-PoC/tree/1_raw_keys) | Raw-keys comparison stack (no CA) - the "old way," right after the concept |
| 2 | [2_revocation](https://github.com/gitmpr/ssh-certs-PoC/tree/2_revocation) (this branch) | Key revocation lists |
| 3 | [3_short-lived_secrets](https://github.com/gitmpr/ssh-certs-PoC/tree/3_short-lived_secrets) | On-demand, short-lived certificate issuance (single CA) |
| 4 | [4_environment_cas](https://github.com/gitmpr/ssh-certs-PoC/tree/4_environment_cas) | Separate CA per environment, plus a root/intermediate signing-key hierarchy |
| 5 | [5_gssapi](https://github.com/gitmpr/ssh-certs-PoC/tree/5_gssapi) | GSSAPI/Kerberos SSH auth - a non-certificate trust model. Ends with Further Reading & Resources. |

up next: [**3_short-lived_secrets**](https://github.com/gitmpr/ssh-certs-PoC/tree/3_short-lived_secrets)
