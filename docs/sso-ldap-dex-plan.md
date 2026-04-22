# SSO, LDAP, and Dex Mapping Plan

This document captures the intended identity flow for the NTU EE Core HPC
Open OnDemand deployment.

## Goal

Keep authentication, identity lookup, and local account policy separate:

- Dex handles authentication with NTU SSO.
- LDAP/SSSD handles identity lookup on the host.
- Open OnDemand handles mapping from authenticated identity to local Unix user.
- A small override table handles exceptions where the Unix username is not the
  student ID.

This avoids putting account provisioning logic into Dex and keeps the site
policy readable.

## Recommended Flow

1. A user authenticates through NTU SSO via Dex.
2. Dex returns a stable identifier in the OIDC claims.
3. OOD calls `user_map_cmd` to turn that identifier into a Unix username.
4. The mapping command checks an override table first.
5. If no override exists, it falls back to the normal student-ID-based lookup.
6. If the resulting Unix user exists through `files` or `sss`, OOD proceeds.
7. If the user does not exist, OOD redirects to `map_fail_uri`.

## Responsibility Split

### Dex

Dex should only authenticate the user and surface stable claims. It should not
create Linux accounts or own provisioning state.

For this deployment, the patched Dex binary is still required because NTU SSO
needs the `userIDAttr` fallback in the SAML connector.

### LDAP and SSSD

LDAP is the authoritative source for normal site identities. SSSD should expose
those identities to the host through NSS.

Expected behavior:

```bash
getent passwd b12901194
id b12901194
```

If those commands succeed, the user should be treated as locally available for
OOD mapping purposes.

### OOD User Mapping

OOD should use `user_map_cmd`, not `user_map_match`, for production mapping.
This allows:

- fallback to LDAP/SSSD-backed users
- explicit overrides for special accounts
- a clean failure path for not-yet-provisioned users

## Default Mapping Rule

For most users, the student ID should map directly to the Unix username:

```text
SSO claim: b12901194@ntu.edu.tw
Unix user: b12901194
```

That should remain the default path.

## Override Table for Special Accounts

Some users use a name-based Unix account instead of a student ID. These should
be handled explicitly through a small override table.

Suggested format:

```text
b12901194=b12901194
prof.wang=wangch
alice.chen=achen
```

Suggested lookup order in the mapping script:

1. Decode the remote user claim.
2. Strip the email domain if present.
3. Check the override table for an exact match.
4. If there is no override, try the stripped value directly.
5. Confirm existence with `getent passwd`.
6. Return success only when the mapped user exists.

This keeps the exception policy explicit and auditable.

## Provisioning Policy

Authentication success should not imply account access.

The policy should be:

- SSO proves who the user is.
- LDAP/SSSD proves the user exists in site identity.
- Local policy decides whether that user may use OOD and Slurm.

For users who are not yet provisioned for access, OOD should redirect them to
the account setup page through `map_fail_uri`.

## Why Not Auto-Create in Dex

Auto-creating local Linux users from Dex would blur too many concerns:

- authentication and system provisioning become tightly coupled
- exception handling gets harder
- local UID/GID policy becomes opaque
- rollback and auditing become harder

If automatic provisioning is ever needed later, it should happen in a separate
approved workflow, not inside Dex.

## Practical Next Step

The next implementation step should be to extend the current
`bin/ood_user_map_exists.sh` script so it:

1. reads an override table from a site-controlled file
2. falls back to the student-ID-based mapping
3. validates the mapped user with `getent passwd`

That gives normal LDAP-backed users an automatic path while preserving manual
control over special accounts.

## Desktop Rollout Note

For additional remote desktop environments, use configuration management rather
than hand-installing packages on individual nodes.

Recommended rollout model:

1. keep `XFCE` as the stable default
2. test one richer desktop on a single node first
3. install required packages with Ansible or image-based provisioning
4. only expose the new desktop in OOD after node-side validation

At the moment, `GNOME Flashback` is a better next candidate than full GNOME
Shell or KDE Plasma for VNC-based OOD sessions. The launcher can live in OOD,
but the desktop packages themselves should be installed consistently across
desktop-capable nodes using Ansible to avoid node drift.
