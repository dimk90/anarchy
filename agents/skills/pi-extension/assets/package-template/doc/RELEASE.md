# Release Instructions

Release from `develop`, merge the reviewed release commit into `master`, and tag
the resulting `master` merge commit. Pushing a stable `vX.Y.Z` tag starts the
`Publish GitHub release` workflow, which publishes the matching `CHANGELOG.md`
section as the GitHub release notes.

> [!Note]
> Automatic checks and release via `scripts/release.sh`

## First publish

`scripts/release.sh` needs a version already on npm, so the first publish is
manual. Version `0.0.1` is a minimal proof of concept that holds the package
name: no merge into `master`, no tag, and no GitHub release.

1. Confirm npm access and that the name is still free (expect a 404):

   ```bash
   pnpm whoami
   ```
   ```bash
   pnpm view {{package}}
   ```

1. Check that `package.json` has version `0.0.1` and replace `Unreleased` for
   `[0.0.1]` in `CHANGELOG.md` with the publish date in `DD.MM.YYYY` format.
   To keep the proof of concept off the pi.dev package list, leave the
   `pi-package` keyword out of `package.json` until the package is stable.

1. Validate the package:

   ```bash
   pnpm check
   ```
   ```bash
   pnpm pack --dry-run
   ```

1. Commit the reviewed files on `develop` and publish from that clean commit.
   Do not push a `v0.0.1` tag: it starts the GitHub release workflow.

   ```bash
   git commit -m "[doc] Release v0.0.1"
   ```
   ```bash
   pnpm publish --no-git-checks --access public
   ```

1. Confirm that npm reports the published version:

   ```bash
   pnpm view {{package}} version
   ```

## Release

Use these steps, or `scripts/release.sh`, for every version after the first
publish.

1. Confirm npm access and make sure the version has not already been published:

   ```bash
   pnpm whoami
   ```
   ```bash
   pnpm view {{package}}
   ```

1. Check the local pi version and update the exact development pin of every
   `@earendil-works/pi-*` package in `package.json` to match it. Keep their
   peer dependencies as `"*"`, then refresh `pnpm-lock.yaml`:

   ```bash
   pi --version
   ```
   ```bash
   pnpm install
   ```

1. Finalize the release documentation:
   - replace `Unreleased` for the version in `CHANGELOG.md` with the release
     date in `DD.MM.YYYY` format;
   - make the changelog entries match the user-visible release notes;
   - if `doc/PLAN.md` exists, remove the completed version section from it,
     leaving future work in the roadmap;
   - verify that README commands, screenshots, and package metadata are current.

1. Check that README image links and the absolute `pi.image` URL resolve to the
   intended immutable image revisions.

1. Bump version number in `package.json`.

1. Review and validate the release tree:

   ```bash
   pnpm check
   ```
   ```bash
   pnpm pack --dry-run
   ```

1. Commit only the reviewed release files, following the repository's release
   commit convention. The release commit covers exactly these paths; commit
   anything else, including reviewed `doc/images` captures, before the release.

   ```bash
   git add CHANGELOG.md package.json pnpm-lock.yaml README.md  # and doc/PLAN.md if changed
   ```
   ```bash
   git commit -m "[doc] Release v0.?.?"
   ```
   ```bash
   git push origin develop
   ```

1. Update `master`, merge `develop`, and validate the exact release tree again:

   ```bash
   git switch master
   ```

   ```bash
   git pull --ff-only origin master
   ```

   ```bash
   git merge --no-ff develop
   ```

1. Tag the tested `master`:
      ```bash
      git tag v0.?.?
      ```

1. Verify the version, tag target, and clean worktree:
      ```bash
      pnpm pkg get version
      ```

1. Push `master` and only the target tag atomically. Do not publish anything if
   this push fails:

   ```bash
   git push --atomic origin master refs/tags/v0.?.?
   ```

1. Wait for the `Publish GitHub release` workflow to complete and verify that
   the release for the target tag is public. Do not publish to npm if the
   workflow fails.

1. Publish only from the clean commit identified by the pushed tag:

   ```bash
   pnpm publish --no-git-checks --access public
   ```

   Wait until npm reports the exact published version. If npm publication fails
   after the GitHub release exists, stop and report the partial release; do not
   delete or replace published artifacts.

1. Return to the `develop` branch:

   ```bash
   git switch develop
   ```
