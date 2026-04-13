# OnDemand Dex Patch Workflow

`../ondemand-dex` is a separate git repository with local
packaging changes for SAML `userIDAttr` fallback support. Do not copy that
entire working tree into this repo.

Use one of these workflows.

## Recommended: fork plus submodule

1. Fork `OSC/ondemand-dex` to your GitHub account.
2. Push the local patch branch from `../ondemand-dex`.
3. Push that branch to your fork.
4. Add it here as a submodule only after the fork URL exists:

```bash
cd ../ondemand-dex
git push -u git@github.com:MarsPresLai/ondemand-dex.git saml-useridattr-fallback

cd ../ondemand
git submodule add -b saml-useridattr-fallback git@github.com:MarsPresLai/ondemand-dex.git vendor/ondemand-dex
git commit -m "chore: add patched ondemand-dex submodule"
```

That lets this repo pin the exact patched Dex package source without vendoring a
second repository into the main tree.

## Lightweight alternative

Keep `ondemand-dex` as a sibling repo and document the expected commit SHA in
the deployment notes. This is simpler locally, but future clones of this repo
will not automatically know which Dex patch to use.

## Current local patch summary

Local branch:

- Repo: `../ondemand-dex`
- Branch: `saml-useridattr-fallback`
- Commit: `676c38e feat: add SAML userIDAttr fallback patch`

The sibling repo currently modifies:

- `packaging/deb/patches/series`
- `packaging/deb/rules`
- `packaging/rpm/ondemand-dex.spec`
- `packaging/deb/patches/0001-saml-useridattr-fallback.patch`

The patch lets Dex use a configured SAML attribute as the stable user ID when
the IdP does not return `Subject/NameID`.
