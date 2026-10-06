# Interoperability fixtures

The `fixtures` directory contains byte-for-byte copies of upstream Bitchat's frozen Nostr private-envelope fixtures and Noise test vectors. Their source paths, pinned upstream commit, and SHA-256 hashes are recorded in `manifest.json`.

These fixtures are test data; the keys embedded in them are published test keys, not application credentials. This directory does not yet contain a Rust interoperability test runner. Upstream Swift fixture tests remain in `apps/macos/bitchatTests`.

Acceptance requires independent receive compatibility with released iOS and Android clients, not just round trips through the same new implementation. Packet framing, malformed input, fragmentation, peer binding, signatures, Noise sessions, and Bitchat's custom Nostr envelopes must be covered as the port proceeds.
