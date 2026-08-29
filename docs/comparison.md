# Certificates vs. raw keys, side by side

The main stack (repo root) demonstrates the certificate model in
isolation. `legacy/` is the same shape - two hosts, one client, roles
`ops`/`dba` - built entirely without a CA, so the two operational pain
points certificates solve are things you can watch happen, not just take
on faith.

Run both walkthroughs and compare directly:

```sh
docker compose up --build -d && ./scripts/revoke-demo.sh
./scripts/legacy-demo.sh
```

## What `legacy/` deliberately does differently

- No CA, no certificates, no `TrustedUserCAKeys`, no `@cert-authority`.
  Just `authorized_keys` and `known_hosts`, the way SSH worked before any
  of that existed.
- No shared volume standing in for a distribution channel. Each host is
  provisioned independently - `scripts/legacy-demo.sh` has to `exec` into
  each one separately to grant access, the same way a real admin (or a
  real Ansible playbook targeting every host in inventory) would.
- Host keys live in the container's own filesystem and regenerate from
  scratch on `--force-recreate`, simulating a real redeploy/rebuild.
  `authorized_keys` lives on a separate per-host volume so it survives
  that - isolating "the host's identity changed" from "who's allowed to
  log in," which is exactly the two things a CA would otherwise both
  handle in one trust decision.

## The two failure modes, head to head

### Host identity changes

| | Certificates (main stack) | Raw keys (`legacy/`) |
|---|---|---|
| Trigger | `web01`'s host key is regenerated (redeploy, rebuild) | `legacy-web01`'s host key is regenerated (`--force-recreate`) |
| Client's reaction | None - the new key is wrapped in a certificate signed by the same CA the client already trusts. Still just works. | `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED`, connection refused |
| Fix required | Nothing, on any client, ever | `ssh-keygen -R <host> -f known_hosts`, by hand, on every client that had ever connected |

### Granting and revoking a person's access

| | Certificates (main stack) | Raw keys (`legacy/`) |
|---|---|---|
| Grant access to N hosts | Issue one certificate, once. Any host trusting the CA accepts it immediately. | Paste the public key into `authorized_keys` on each of the N hosts, individually |
| Where "who has access to what" lives | The CA's issuance record (one place) | Scattered across every host's `authorized_keys` (N places, nothing central) |
| Revoke access | One `revoke.sh` call updates one KRL; every host re-reads it on the next connection | Must be found and deleted from `authorized_keys` on every host it was ever pasted to - miss one, and access silently persists there |

`scripts/legacy-demo.sh` step 6 makes that last row concrete: access is
revoked on `legacy-web01`, and deliberately *not* on `legacy-db01`, and the
old key keeps working there because nothing forced anyone to remember
every host it had been granted on. `scripts/revoke-demo.sh` shows the same
scenario solved with one command that every host observes immediately.

## What doesn't change

Both stacks still need `sshd` correctly configured, still authenticate
with public-key cryptography under the hood, and still benefit from the
same operational hygiene (least privilege, monitoring, patching). None of
that goes away. What changes is *how many places a trust decision has to
be made and re-made* - once per identity with certificates, once per
identity **times** every host it touches without them. See chapter 0's
["The problem"](https://github.com/gitmpr/ssh-certs-PoC/blob/main/README.md#the-problem)
section for the *N x M* framing this collapses.
