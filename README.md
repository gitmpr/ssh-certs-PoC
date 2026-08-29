# ssh-certs-PoC — Chapter 4: Per-Environment CAs & an Intermediate-Key Hierarchy

> Continues from [**3_short-lived_secrets**](https://github.com/gitmpr/ssh-certs-PoC/tree/3_short-lived_secrets) and everything before it. All prior chapters are assumed knowledge here.

Chapters 2 and 3 were *lifecycle* refinements to chapter 0's single CA -
kill a certificate early, or don't need to. This chapter is a *topology*
change: more than one CA, and a hierarchy above them.

## Separate CAs per environment, plus a root

`environments/` is a third, self-contained stack: two environments
(`staging`, `prod`), each with its own **intermediate CA**, both minted by
a single **root CA** that mints them, signs a delegation certificate over
each one's public key, and then goes cold - never used again.

```sh
./scripts/environment-cas-demo.sh
```

It reuses chapter 3's on-demand issuance (`ca/issue.sh`, now one instance
per environment) to get alice a staging certificate, uses it successfully,
shows the *exact same* certificate rejected against `prod-web01` (not
because anything about it is wrong - it's simply signed by a CA that host
has never heard of), issues a prod certificate too from alice's same
underlying key pair, and finally verifies - by comparing fingerprints, not
by asserting it - that root, not the intermediate itself, actually signed
the delegation certificate backing each environment's CA.

**Worth being precise about**: SSH has no X.509-style certificate chain
validation. `TrustedUserCAKeys`/`@cert-authority` only ever list flat,
directly-trusted keys - nothing in sshd or ssh walks a chain up to a root
it trusts. The delegation certificate `root-ca/` produces is an *audit*
record - proof that root approved a given intermediate - checked here by
hand (`ssh-keygen -Lf`, then comparing the delegation cert's `Signing CA`
fingerprint against root's own), not something any SSH software enforces
automatically. See [`environments/root-ca/entrypoint.sh`](environments/root-ca/entrypoint.sh)
and [docs/production.md](docs/production.md) for the real-world version of
this pattern - root CAs kept offline/in an HSM, intermediates doing the
daily signing.

This is a second, independent trust axis from `AuthorizedPrincipalsFile`
(chapters 0-3): there, a valid certificate could still be refused for the
*wrong role*. Here, a valid certificate for the *right* role is refused
for belonging to the *wrong environment*.

## New in this chapter

```
environments/                staging + prod, each with its own intermediate CA:
                              docker-compose.yml, root-ca/ (mints + delegates,
                              then goes cold), ca/ (per-environment, now consumes
                              root-ca's keys instead of generating its own),
                              hosts/, client/
scripts/environment-cas-demo.sh   guided walkthrough: issuance, isolation, delegation
docs/cheatsheet.md            (updated) CertificateFile; reissuing certs against a
                               shared key pair
docs/production.md            (updated) environment-isolation row now points here;
                               new "Bastion and jump hosts" section
```

## Chapters

This repo uses branches as chapters, each one building on the last:

| Chapter | Branch | Adds |
|---|---|---|
| 0 | [main](https://github.com/gitmpr/ssh-certs-PoC/tree/main) | CA, host certificates, user certificates, principals |
| 1 | [1_raw_keys](https://github.com/gitmpr/ssh-certs-PoC/tree/1_raw_keys) | Raw-keys comparison stack (no CA) - the "old way," right after the concept |
| 2 | [2_revocation](https://github.com/gitmpr/ssh-certs-PoC/tree/2_revocation) | Key revocation lists |
| 3 | [3_short-lived_secrets](https://github.com/gitmpr/ssh-certs-PoC/tree/3_short-lived_secrets) | On-demand, short-lived certificate issuance (single CA) |
| 4 | [4_environment_cas](https://github.com/gitmpr/ssh-certs-PoC/tree/4_environment_cas) (this branch) | Separate CA per environment, plus a root/intermediate signing-key hierarchy |
| 5 | [5_gssapi](https://github.com/gitmpr/ssh-certs-PoC/tree/5_gssapi) | GSSAPI/Kerberos SSH auth - a non-certificate trust model. Ends with Further Reading & Resources. |

up next: [**5_gssapi**](https://github.com/gitmpr/ssh-certs-PoC/tree/5_gssapi)
