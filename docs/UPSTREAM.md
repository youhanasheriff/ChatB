# Upstream provenance

BitChat Desktop follows [permissionlesstech/bitchat](https://github.com/permissionlesstech/bitchat) as an independently maintained desktop project.

The initial imported source is commit `5e9287fae1e5fea80ca741d4ea669829dc16f144`. Git history is retained through a public fork, and the local `upstream` remote points to Bitchat.

## Initial changes

- Moved the Apple implementation and supporting packages into `apps/macos`.
- Renamed the Xcode project, macOS scheme, and macOS application product to BitChat Desktop.
- Set a separate bundle/app-group identity and removed the upstream signing team.
- Retained internal Swift module names and wire identifiers to limit compatibility changes.
- Added a Rust workspace and directory scaffolds for native Windows/Linux clients.
- Copied independent compatibility fixtures with a SHA-256 manifest.
- Replaced active upstream workflows with monorepo CI. Original workflow snapshots and the upstream README are retained under `docs/upstream`; they are historical references and their old repository-relative paths are not current instructions.
- Updated the active Arti artifact provenance paths to the new location.

## Follow upstream

Fetch updates with `git fetch upstream`. Review protocol and security changes against the pinned snapshot, apply changes to the relocated Apple implementation and future shared core, then run interoperability checks. The upstream tree has a different layout; merging updates requires review rather than a blind replacement.

Keep protocol identifiers, signature rules, envelopes, and session behavior aligned with the selected upstream release. Track feature support separately for each platform.

## License and dependencies

Original BitChat Desktop contributions use the [MIT License](../LICENSE), except where a file states otherwise. The inherited Bitchat source retains its Unlicense dedication, preserved verbatim in [LICENSES/Bitchat-Unlicense.txt](../LICENSES/Bitchat-Unlicense.txt). Existing author/source notices remain. Arti and other dependencies retain their respective licenses and provenance. Redistribution requires carrying the relevant license and dependency notices. Previously published versions retain their original license grants.

BitChat Desktop does not claim to be an official Bitchat distribution.
