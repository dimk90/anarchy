# Changelog

## [0.0.1] - Unreleased

### New
* `[{{scope}}]` {{User-visible addition, one line, imperative mood.}}

### Changed
* `[{{scope}}]` {{User-visible behavior change.}}

### Fixed
* `[{{scope}}]` {{User-visible fix.}}

<!--
Conventions:
- Newest version first; `## [X.Y.Z] - DD.MM.YYYY`, `Unreleased` until release.
  No `v` prefix or backticks: Pi parses these headings to show the entries
  newer than the installed version after a package update.
- Sections in order: New, Changed, Fixed; omit empty ones.
- Every entry starts with a `[scope]` tag matching the commit-message scopes
  used in the repository (e.g. `[usage]`, `[ui]`, `[doc]`, `[package]`).
- Entries describe user-visible effects, not internal refactors.
- Keep each entry's text after the `[scope]` tag to about 80 characters.
- Raising MIN_PI_VERSION gets a `[package] Require Pi X.Y.Z ...` entry; a
  dev-pin-only Pi bump needs none.
-->
