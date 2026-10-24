# Publishing

## What it is

Shipping the package to pub.dev: the manifest and SDK floor, what goes into
the archive, the public docs a consumer reads (README, CHANGELOG, LICENSE),
versioning, and dependency updates. A release is a `Prepare x.y.z` commit
merged through a `chore/release-*` pull request; no CI workflow publishes.

## Governing decisions

**None.** No decision record exists.

## Design model

- **The floor is inherited downstream.** The packages in
  [Adoption](../../adoption.md) depend on this one, so its SDK floor and
  dependency constraints are the lowest they can resolve.
- **`.pubignore` replaces `.gitignore`**, so it repeats the git ignores that
  can appear on disk, then adds the repository-only files (`docs/`,
  `CLAUDE.md`).
- **`.github/` stays out of the archive without a `.pubignore` line**:
  `flutter pub publish --dry-run` lists no `.github/`.
- **Dependabot watches the root pub constraints weekly**, with
  `increase-if-necessary` and the `needs-triage` label. The root commits no
  lockfile, so a PR opens only when a release falls outside the caret; at
  `0.x` every minor release does, and each such PR is a floor decision for
  consumers rather than a chore, so root PRs stay one per dependency. The
  only non-SDK dependency is dev `flutter_lints`. A run with every dependency
  inside its caret succeeds and opens nothing, so no PR is the healthy state;
  the run's status is under the repository's Dependabot jobs.
- **Root only, weekly**: the maintainer's call on #25, against the ticket's
  monthly interval and the siblings that also watch `/example`. Nothing ships
  from `example/`. No `github-actions` entry, because the repository has no
  workflow.

## Code

- `pubspec.yaml`, `.pubignore`, `.github/dependabot.yml`, `CHANGELOG.md`,
  `README.md`, `LICENSE`, `lib/flutter_smooth_wheel_scroll.dart` (the export
  surface).

## Reference behaviour

**None.**

## Cross-cutting invariants

- [SDK floor](../invariant/sdk-floor.md) — the `environment` this manifest
  declares.

## Blast radius

- The packages in [Adoption](../../adoption.md) — a raised constraint here
  narrows their resolution.
- `example/` — ships in the archive, including `example/web/` and
  `example/windows/`; pub.dev's example tab reads `example/lib/main.dart` and
  `example/README.md`.

## Known holes / open

- No CI: nothing runs `flutter analyze`, the tests or the publish dry run on a
  pull request, so a Dependabot PR arrives with no gate.
- A release inside the caret reaches no PR: with no root lockfile, Dependabot
  has nothing to update until the caret is outgrown.- How a release is cut is not written down beyond the commit and branch names.
