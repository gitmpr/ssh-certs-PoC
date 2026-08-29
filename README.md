# ssh-certs-PoC — Chapter 1: Raw Keys, Compared

> Continues from [**main**](https://github.com/gitmpr/ssh-certs-PoC/tree/main) - the CA, host certificates, user certificates, and principals covered there are assumed knowledge here. Start there first if you haven't.

Chapter 0 argued, in prose, that plain SSH keys ask two questions -
"is this really the server?" and "should this server let this person
in?" - and answer both badly at scale. This chapter rebuilds that
argument as something you run and watch, rather than take on faith:
the same two-hosts-one-client shape as chapter 0, with no CA at all.

## Compared to raw keys

`legacy/` is a separate, self-contained stack - plain `authorized_keys`
and TOFU `known_hosts`, the way SSH worked before certificates existed.
`scripts/legacy-demo.sh` runs through granting access host by host, a
simulated host rebuild that breaks every client's `known_hosts`, and
"revoking" access by hand on one host while forgetting a second one
entirely:

```sh
./scripts/legacy-demo.sh
```

[docs/comparison.md](docs/comparison.md) lays the two models side by
side, failure mode by failure mode - the concrete version of chapter 0's
["problem"](https://github.com/gitmpr/ssh-certs-PoC/blob/main/README.md#the-problem)
section.

This chapter deliberately doesn't touch anything from chapter 0 - `legacy/`
is its own `docker-compose.yml`, its own hosts, its own client. Chapters
2 onward build forward *on* the certificate model instead.

## New in this chapter

```
legacy/                   raw-keys comparison stack: its own docker-compose.yml, hosts/, client/
scripts/legacy-demo.sh    guided raw-keys walkthrough (run from the host machine)
docs/comparison.md        certificates vs. raw keys, failure mode by failure mode
```

## Chapters

This repo uses branches as chapters, each one building on the last:

| Chapter | Branch | Adds |
|---|---|---|
| 0 | [main](https://github.com/gitmpr/ssh-certs-PoC/tree/main) | CA, host certificates, user certificates, principals |
| 1 | [1_raw_keys](https://github.com/gitmpr/ssh-certs-PoC/tree/1_raw_keys) (this branch) | Raw-keys comparison stack (no CA) - the "old way," right after the concept |
| 2 | [2_revocation](https://github.com/gitmpr/ssh-certs-PoC/tree/2_revocation) | Key revocation lists |
| 3 | [3_short-lived_secrets](https://github.com/gitmpr/ssh-certs-PoC/tree/3_short-lived_secrets) | On-demand, short-lived certificate issuance (single CA) |
| 4 | [4_environment_cas](https://github.com/gitmpr/ssh-certs-PoC/tree/4_environment_cas) | Separate CA per environment, plus a root/intermediate signing-key hierarchy |
| 5 | [5_gssapi](https://github.com/gitmpr/ssh-certs-PoC/tree/5_gssapi) | GSSAPI/Kerberos SSH auth - a non-certificate trust model. Ends with Further Reading & Resources. |

up next: [**2_revocation**](https://github.com/gitmpr/ssh-certs-PoC/tree/2_revocation)
