# Security

BitChat Desktop is an independently maintained desktop project following Bitchat. Its new shared core and Windows/Linux clients are not implemented or audited yet.

Report security vulnerabilities privately through [GitHub private vulnerability reporting](https://github.com/youhanasheriff/bitchat-desktop/security/advisories/new). Avoid publishing sensitive proof-of-concept details before a fix is available.

For an issue affecting unchanged upstream Bitchat code, identify the pinned source revision and coordinate with [Bitchat's security process](https://github.com/permissionlesstech/bitchat/blob/main/SECURITY.md).

Relevant areas include identity/key storage, Noise sessions, private Nostr envelopes, packet validation, mesh routing, media handling, Tor behavior, and wipe/retention semantics. Do not claim compatibility, confidentiality, or audit coverage beyond the implementation and verification actually completed.
