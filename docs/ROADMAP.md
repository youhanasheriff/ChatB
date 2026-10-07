# BitChat Desktop Roadmap

A living implementation checklist for the [vision and mission](VISION-AND-MISSION.md). It covers the known work from the current scaffold to a supported native desktop release and ongoing upstream maintenance. Newly discovered requirements must be added explicitly; this is not a claim that future upstream changes can be predicted.

Last reviewed: **October 6, 2026**. Stable-release work is in sections 0–26; section 27 records separate future decisions.

## Navigation

- Foundation: [repository](#0-repository-foundation), [scope](#1-define-the-supported-product-and-compatibility-contract), [radio feasibility](#2-prove-desktop-bluetooth-feasibility-early).
- Shared engine: [architecture](#3-shared-architecture-and-native-boundary), [wire codecs](#4-protocol-codecs-and-packet-validation), [cryptography](#5-identity-authentication-and-encrypted-sessions), [routing](#6-mesh-state-routing-and-scheduling), [Bluetooth adapters](#7-production-bluetooth-adapters).
- Delivery and privacy: [offline exchange](#8-delivery-persistence-and-offline-exchange), [Nostr](#9-nostr-and-internet-transport), [Tor](#10-tor-and-network-privacy), [secure storage](#11-secure-storage-and-identity-lifecycle).
- Native apps: [macOS](#12-native-macos-client), [Windows](#13-native-windows-client), [Linux](#14-native-linux-client).
- Features: [desktop experience](#15-shared-desktop-conversation-experience), [groups and trust](#16-groups-verification-and-trust-features), [media and voice](#17-images-files-voice-notes-and-live-voice), [location and boards](#18-location-channels-boards-and-nearby-notes), [bridging](#19-gateway-bridge-and-mesh-diagnostics).
- Release readiness: [security/privacy](#20-privacy-abuse-resistance-and-reset-behavior), [verification](#21-compatibility-and-quality-verification), [size budgets](#22-application-size-startup-and-resource-budgets), [CI](#23-build-automation-and-contributor-workflow), [distribution](#24-packaging-distribution-and-updates).
- Stewardship: [maintenance](#25-open-source-maintenance-and-upstream-tracking), [stable-release gates](#26-stable-release-acceptance-checklist), [deferred decisions](#27-explicitly-deferred-or-separate-decisions).

## How to use this checklist

- `[x]` means the stated task has evidence; it does not imply an entire feature or platform is complete.
- `[ ]` means work or verification remains. The inherited macOS code may already contain an implementation that still needs qualification or a Rust port.
- IDs such as `WIRE-01` are stable references for issues, commits, and reviews. Append new IDs rather than renumbering existing ones.
- For a feature spanning platforms, keep its item open until all platforms in its declared support matrix have evidence. Track platform-specific results in the linked issue/matrix.
- Record owner, issue/PR, source revision, CI run, and hardware/client versions when work starts or finishes. A generated folder or passing empty crate is not feature completion.
- A removed/deferred requirement needs a documented scope decision. Do not check it off as implemented.
- Dates and numeric budgets are set after measurement and feasibility work; milestone order is a dependency plan, not a release-date promise.

## Verified starting point

Baseline: BitChat Desktop setup commit `1bb00da`, following Bitchat `5e9287fae1e5fea80ca741d4ea669829dc16f144`. Repository: [youhanasheriff/bitchat-desktop](https://github.com/youhanasheriff/bitchat-desktop).

[Initial CI run](https://github.com/youhanasheriff/bitchat-desktop/actions/runs/37473129802): Rust scaffolding passed on macOS, Windows, and Linux; both Swift package jobs and fixture/provenance checks passed. The complete macOS Release build failed because the relocated project referenced the relay CSV at its old path. Commit `922e0ee` corrected that reference; the [follow-up CI run](https://github.com/youhanasheriff/bitchat-desktop/actions/runs/37473910185) passed, including the complete macOS Release build. Application launch and physical interoperability remain unverified.

| Area | Current evidence | Remaining distinction |
|---|---|---|
| macOS | Inherited SwiftUI/CoreBluetooth code, BitChat Desktop product identity, passing package tests and complete Release build | Launch, application tests, and physical interoperability still need qualification |
| Windows | Directory scaffold; Rust workspace compiles in Windows CI | No native Windows client or Bluetooth implementation |
| Linux | Directory scaffold; Rust workspace compiles in Linux CI | No native Linux client or Bluetooth implementation |
| Shared Rust | Three compiling workspace crates | Protocol, core, and FFI behavior are not implemented |
| Fixtures | Six copied upstream fixtures and seven Arti artifact hashes verified | Rust conformance runner and broader independent vectors remain |
| Size | Small macOS UI probes in the research report | No finished BitChat Desktop installation size measured |

## Milestones and dependencies

| Milestone | Scope | Depends on | Exit evidence |
|---|---|---|---|
| M0 — Foundation | Public repo, layout, attribution, scaffolding, initial checks | — | Setup committed and published; remaining implementation explicit |
| M1 — Native baseline | Working Mac baseline, scope/support matrix, repeatable builds | M0 | Mac app builds/launches; supported behavior and test peers identified |
| M2 — Radio feasibility | Windows/Linux central and peripheral proofs | M0 + defined protocol target | Real iOS/Android exchanges on documented hardware |
| M3 — Shared protocol | Codecs, authentication, core boundaries, independent fixtures | M1 + M2 findings | Rust conformance evidence and defined native integration contract |
| M4 — Mesh alpha | Native apps with nearby public/private text and core reliability | M2 + M3 | All declared desktop peers exchange verified mesh messages |
| M5 — Internet beta | Nostr, Tor, secure persistence, offline delivery | M4 | Compatible delivery and privacy behavior through failure/recovery |
| M6 — Feature-parity beta | Supported groups, media, voice, channels, boards, bridging, desktop polish | M4/M5 as relevant | Agreed feature matrix passes across target clients/platforms |
| M7 — Stable release | Hardening, performance budgets, signed packages, docs, update/recovery | M1–M6 | Every stable-release gate below is evidenced |

Within these milestones, packet correctness, secure identity handling, platform feasibility, and working end-to-end text take priority over advanced features. An earlier platform preview may ship with an explicitly limited scope; it must not be described as full cross-platform parity.

## Immediate next actions

1. Launch the macOS app and qualify its application behavior and physical-device interoperability.
2. Inventory shipping versus reserved upstream packet/capability behavior and freeze the first compatibility matrix.
3. Prove Windows and Linux Bluetooth central/peripheral behavior on actual hardware.
4. Implement the Rust packet codec plus an independent fixture runner.
5. Deliver the first verified public/private text exchange through each native client.

## Completion evidence

A feature is done when its required implementation, positive/negative checks, upstream interoperability, platform integration, error/recovery behavior, user-facing states, and documentation are complete. For release-affecting changes, include size/resource impact and packaging verification. Mark exceptions with a scoped limitation and supporting evidence.

## 0. Repository foundation

**Milestone:** M0 / M1. **Exit condition:** The project is public, attributable, and organized; implementation completeness is tracked separately.

- [x] **FND-01** Publish BitChat Desktop under the personal `youhanasheriff` GitHub account as a public Bitchat fork.
- [x] **FND-02** Retain upstream Git history, author/source notices, and the upstream Unlicense in `LICENSES/Bitchat-Unlicense.txt`. Original project contributions use MIT.
- [x] **FND-03** Keep `origin` pointing to BitChat Desktop and `upstream` pointing to Bitchat.
- [x] **FND-04** Create `apps/macos`, `apps/windows`, and `apps/linux`.
- [x] **FND-05** Create the protocol, core, and FFI Rust workspace crates.
- [x] **FND-06** Create platform, interop-test, packaging, and documentation directories.
- [x] **FND-07** Move the Apple project, packages, configuration, and tests into `apps/macos`.
- [x] **FND-08** Set the macOS product/scheme to BitChat Desktop and assign a separate bundle/app-group identity.
- [x] **FND-09** Remove the inherited signing team from shared build configuration.
- [x] **FND-10** Preserve independent Noise/Nostr fixtures with a source and SHA-256 manifest.
- [x] **FND-11** Preserve and verify the vendored Arti artifact hashes after relocation.
- [x] **FND-12** Add CI for the Rust workspace on macOS, Windows, and Linux.
- [x] **FND-13** Pass the Rust scaffold checks on all three CI operating systems.
- [x] **FND-14** Pass 184 BitFoundation and 13 BitLogger tests locally and in the initial CI run.
- [x] **FND-15** Pass the inherited Python tests and fixture/provenance checks.
- [x] **FND-16** Correct the relay CSV resource reference missed during the Apple project move; commit `922e0ee`.
- [x] **FND-17** Obtain a successful complete macOS Release build after the resource-path correction; commit `922e0ee`, CI run `37473910185` (before the branding rename).
- [ ] **FND-18** Run the complete inherited application test suite and classify remaining failures.
- [ ] **FND-19** Launch the built macOS app and verify identity storage, permissions, and a basic conversation.

## 1. Define the supported product and compatibility contract

**Milestone:** M1. **Exit condition:** A reviewed compatibility matrix names exactly what each release promises.

- [ ] **SCP-01** Record the selected Bitchat Apple revision and corresponding Android release/commit used for interoperability.
- [ ] **SCP-02** Inventory every packet type, payload subtype, advertised capability, command, storage format, and user-visible feature from the pinned source.
- [ ] **SCP-03** Classify each upstream item as shipping, conditional, experimental, reserved, or deprecated using dispatch paths and real-client evidence.
- [ ] **SCP-04** Create a per-feature macOS/Windows/Linux matrix with implemented, tested, unavailable, and deferred states.
- [ ] **SCP-05** Set minimum supported OS versions and CPU architectures; distinguish tested targets from planned targets.
- [ ] **SCP-06** Select the first supported Linux distributions and desktop environments.
- [ ] **SCP-07** Define which Bluetooth adapters/drivers are supported and what degraded operation means.
- [ ] **SCP-08** Define the first mesh alpha, internet beta, feature-parity beta, and stable release scope.
- [ ] **SCP-09** Map each claimed feature to independent fixtures, integration tests, and physical-device acceptance evidence.
- [ ] **SCP-10** Define backward compatibility and an upstream-version support policy.
- [ ] **SCP-11** Create a decision log for package choices, platform limitations, scope changes, and privacy tradeoffs.
- [ ] **SCP-12** Track each started roadmap item with an owner, issue/PR, target milestone, and evidence.

## 2. Prove desktop Bluetooth feasibility early

**Milestone:** M2. **Exit condition:** Each proposed platform can perform the required radio roles on documented physical hardware.

- [ ] **RAD-01** Create a small Windows transport proof that scans for the pinned Bitchat service.
- [ ] **RAD-02** Create a small Linux transport proof that scans for the same service.
- [ ] **RAD-03** Prove peripheral advertising and GATT-server operation on Windows hardware.
- [ ] **RAD-04** Prove peripheral advertising and GATT-server operation on Linux hardware.
- [ ] **RAD-05** Prove simultaneous scanning, advertising, central links, and peripheral links where full participation requires them.
- [ ] **RAD-06** Exchange bidirectional GATT writes and notifications with actual Bitchat iOS and Android devices.
- [ ] **RAD-07** Measure negotiated payload limits and transfer behavior across the selected adapters.
- [ ] **RAD-08** Test permission denial, unavailable Bluetooth, radio toggles, and adapter removal.
- [ ] **RAD-09** Test disconnect/reconnect, sleep/resume, and OS Bluetooth-service restart.
- [ ] **RAD-10** Document any unsupported peripheral role or driver constraint and present an honest user-visible mode.
- [ ] **RAD-11** Record OS, architecture, adapter chipset, driver version, peer versions, and test logs.
- [ ] **RAD-12** Resolve feasibility blockers before committing to large platform-specific UI or protocol ports.

## 3. Shared architecture and native boundary

**Milestone:** M3. **Exit condition:** The core can run deterministically without importing a desktop UI or a platform radio API.

- [ ] **ARC-01** Define the protocol/core/app responsibilities and dependency direction.
- [ ] **ARC-02** Define typed transport events and commands for connection, receive, send, backpressure, and shutdown.
- [ ] **ARC-03** Define identity, secure storage, clock, entropy, persistence, and network interfaces.
- [ ] **ARC-04** Specify session, peer, conversation, and message identifiers without confusing transport addresses with trusted identity.
- [ ] **ARC-05** Choose an async runtime and execution model from measured requirements and supported platforms.
- [ ] **ARC-06** Specify ordering, cancellation, timeouts, bounded queues, and reconnection ownership.
- [ ] **ARC-07** Keep UI state changes on the native UI thread and prevent callbacks after object teardown.
- [ ] **ARC-08** Design a narrow versioned C ABI for callers that need it; let Rust callers use the core directly when appropriate.
- [ ] **ARC-09** Specify FFI buffer ownership, lengths, allocation/free pairs, string encoding, and error mapping.
- [ ] **ARC-10** Specify callback lifetime, thread affinity, reentrancy, and shutdown/drain behavior.
- [ ] **ARC-11** Prevent Rust panics or foreign exceptions from crossing the ABI boundary.
- [ ] **ARC-12** Generate or validate native bindings and provide a real lifecycle smoke test.
- [ ] **ARC-13** Define a staged Mac migration plan that keeps the existing Swift implementation available until the Rust replacement passes conformance.

## 4. Protocol codecs and packet validation

**Milestone:** M3. **Exit condition:** Independent upstream bytes decode correctly, and generated packets are accepted by the selected clients.

- [ ] **WIRE-01** Port binary primitives, byte order, bounded lengths, timestamps, and integer conversions.
- [ ] **WIRE-02** Port packet headers, sender/recipient IDs, versions, flags, optional fields, and payload framing.
- [ ] **WIRE-03** Port message-type and capability encodings, preserving reserved assignments and unknown-bit handling.
- [ ] **WIRE-04** Port announce packets and identity/key bindings; distinguish direct and relayed presence.
- [ ] **WIRE-05** Port public text, leave, encrypted-container, receipt, and application payload codecs.
- [ ] **WIRE-06** Port file, private-media, group, board, gateway/carrier, and voice payload codecs required by the declared feature set.
- [ ] **WIRE-07** Port courier envelope, prekey bundle, ping/pong, and sync codecs according to their verified upstream status.
- [ ] **WIRE-08** Match canonical signing bytes, TTL normalization, field ordering, and signature placement.
- [ ] **WIRE-09** Match compression, padding, and unpadding rules without allowing decompression bombs.
- [ ] **WIRE-10** Match packet/message IDs and cross-transport deduplication inputs.
- [ ] **WIRE-11** Implement unknown-version/type behavior without interpreting unsupported data as another packet.
- [ ] **WIRE-12** Reject truncation, invalid UTF-8 where required, duplicate/disallowed fields, impossible lengths, and over-limit payloads.
- [ ] **WIRE-13** Port fragmentation headers, reassembly keys, ordering rules, and missing/duplicate-fragment behavior.
- [ ] **WIRE-14** Bound concurrent assemblies, total buffered bytes, fragment counts, expiry, and conflicting fragments.
- [ ] **WIRE-15** Build the Rust fixture loader for the imported vectors and add independent binary golden vectors.
- [ ] **WIRE-16** Differentially test the Rust codecs against the pinned Swift implementation.
- [ ] **WIRE-17** Fuzz all externally reachable parsers and preserve minimized regression inputs.
- [ ] **WIRE-18** Document schema evolution and acceptance rules with source references.

## 5. Identity, authentication, and encrypted sessions

**Milestone:** M3. **Exit condition:** Cryptographic behavior matches independent vectors and real peers, including negative and recovery cases.

- [ ] **CRYPTO-01** Select maintained cryptographic libraries and review supported algorithms, licenses, platform support, and footprint.
- [ ] **CRYPTO-02** Port compatible identity generation, encoding, persistence, key derivation, and public-key relationships.
- [ ] **CRYPTO-03** Use OS-backed cryptographic randomness and fail safely when it is unavailable.
- [ ] **CRYPTO-04** Implement compatible Ed25519 signing/verification and required key encodings.
- [ ] **CRYPTO-05** Implement the pinned Noise XX suite, handshake transcript, role transitions, and transport encryption.
- [ ] **CRYPTO-06** Bind completed sessions to the authenticated peer identity; reject mismatched outer/inner identities.
- [ ] **CRYPTO-07** Handle simultaneous handshake initiation, duplicate messages, timeouts, reconnects, and session replacement.
- [ ] **CRYPTO-08** Enforce nonce/counter rules, replay rejection, invalid-tag rejection, and key lifetime limits.
- [ ] **CRYPTO-09** Port one-way/offline sealing only with its actual upstream semantics and documented forward-secrecy limits.
- [ ] **CRYPTO-10** Review how prekeys are actually used; preserve validation, consumption, expiry, and reuse protections where implemented.
- [ ] **CRYPTO-11** Implement required secp256k1/Schnorr/ECDH, HKDF, and XChaCha20-Poly1305 operations for the custom Nostr envelope.
- [ ] **CRYPTO-12** Verify malformed keys, invalid signatures, mismatched recipients, and nested sender-binding failures.
- [ ] **CRYPTO-13** Keep secrets out of logs/errors and clear sensitive temporary buffers where the implementation permits.
- [ ] **CRYPTO-14** Run independent Noise and envelope fixtures in both directions between Rust and the reference implementation.
- [ ] **CRYPTO-15** Document what each messaging path protects and what metadata and compromise scenarios remain exposed.

## 6. Mesh state, routing, and scheduling

**Milestone:** M4. **Exit condition:** The shared engine behaves predictably under churn, duplication, congestion, and shutdown.

- [ ] **CORE-01** Implement peer lifecycle, verified presence, expiry, reachability, and display-name resolution.
- [ ] **CORE-02** Implement connection scheduling, retry backoff, jitter, connection limits, and fairness.
- [ ] **CORE-03** Implement announce throttling, scan duty behavior, and disconnected/connected maintenance policies.
- [ ] **CORE-04** Implement broadcast forwarding, hop/TTL handling, freshness checks, and loop prevention.
- [ ] **CORE-05** Implement bounded deduplication and distinguish self-echoes from new messages.
- [ ] **CORE-06** Implement topology tracking and source routing only to the extent used by the selected upstream release.
- [ ] **CORE-07** Implement route failure, stale topology, fallback, and redundant-link handling.
- [ ] **CORE-08** Implement per-link authentication state and reject untrusted identity substitutions.
- [ ] **CORE-09** Implement bounded outbound queues, write/notification backpressure, and transfer fairness.
- [ ] **CORE-10** Preserve control-message responsiveness while large media transfers are active.
- [ ] **CORE-11** Implement cancellation, disconnect cleanup, and deterministic engine shutdown.
- [ ] **CORE-12** Add local-only counters and structured redacted diagnostics for routing failures.
- [ ] **CORE-13** Test clock changes, duplicate events, delayed callbacks, partition/rejoin, and queue saturation with deterministic simulations.

## 7. Production Bluetooth adapters

**Milestone:** M4. **Exit condition:** All native adapters satisfy the same transport contract and recover from realistic OS events.

- [ ] **BLE-01** Wrap the existing macOS CoreBluetooth central and peripheral behavior behind the adapter contract.
- [ ] **BLE-02** Implement Windows device discovery, service discovery, GATT client writes, and notifications.
- [ ] **BLE-03** Implement Windows GATT service publication and advertising with runtime capability checks.
- [ ] **BLE-04** Implement Linux Bluetooth discovery, GATT client/server registration, and advertising through the selected system integration.
- [ ] **BLE-05** Match service/characteristic UUIDs, characteristic properties, subscription behavior, and wire framing.
- [ ] **BLE-06** Translate negotiated MTU/payload limits into the shared fragmentation and send scheduler.
- [ ] **BLE-07** Serialize platform API calls and respect each OS callback/lifecycle contract.
- [ ] **BLE-08** Bound per-peer receive buffers and reject data before expensive parsing where possible.
- [ ] **BLE-09** Handle permissions, daemon/service restarts, adapter replacement, and unavailable peripheral support.
- [ ] **BLE-10** Handle sleep/resume and radio toggles without orphaning subscriptions or advertising state.
- [ ] **BLE-11** Prevent resource leaks when peers reconnect repeatedly or the app exits during transfers.
- [ ] **BLE-12** Verify unsigned development builds and the intended signed/sandboxed package separately.
- [ ] **BLE-13** Repeat the hardware matrix after material OS, driver, packaging, or adapter changes.

## 8. Delivery, persistence, and offline exchange

**Milestone:** M4 / M5. **Exit condition:** Delivery status reflects evidence, and queued messages survive or expire according to documented policy.

- [ ] **DEL-01** Implement distinct queued, sent, delivered, read, expired, cancelled, and failed states.
- [ ] **DEL-02** Match text and media receipt formats, correlation identifiers, and idempotency.
- [ ] **DEL-03** Persist the private outbox with protected keys, bounded capacity, expiry, and retry limits.
- [ ] **DEL-04** Implement reconnect-triggered retry without repeated user-visible duplicates.
- [ ] **DEL-05** Implement courier deposit eligibility, trust tiers, quotas, envelope validation, and copy budgets.
- [ ] **DEL-06** Implement courier handover, spray/retry history, expiry, and restart recovery as supported upstream.
- [ ] **DEL-07** Implement blocked-sender checks when carried mail is decrypted.
- [ ] **DEL-08** Implement public-history archive, sync filters, request/response rules, and anti-amplification limits.
- [ ] **DEL-09** Preserve per-type retention rules, including ephemeral traffic excluded from history sync.
- [ ] **DEL-10** Handle crash recovery, partial writes, disk full, damaged records, and schema migration.
- [ ] **DEL-11** Test multiple delivery paths racing to deliver the same message and receipt.
- [ ] **DEL-12** Expose useful failure/retry information without implying that a local send proves remote delivery.

## 9. Nostr and internet transport

**Milestone:** M5. **Exit condition:** Internet messaging interoperates with the selected clients and obeys the chosen privacy mode.

- [ ] **NET-01** Implement relay URL validation, WebSocket lifecycle, subscriptions, reconnects, and backoff.
- [ ] **NET-02** Validate event IDs, signatures, authors, kinds, tags, timestamps, and size limits before use.
- [ ] **NET-03** Implement Bitchat's proprietary private envelope rather than substituting standard NIP-17/44/59 DM behavior.
- [ ] **NET-04** Match layered encryption, recipient addressing, sender binding, timestamp treatment, and `bitchat1:` embedded payloads.
- [ ] **NET-05** Verify mutual-favorite identity exchange, identity bridging, mailbox subscriptions, and lookback windows.
- [ ] **NET-06** Implement bounded event deduplication across relays and restarts.
- [ ] **NET-07** Implement delivery/read semantics supported by this transport without manufacturing acknowledgments.
- [ ] **NET-08** Implement public geohash channel events, subscriptions, presence, and participant state.
- [ ] **NET-09** Preserve any required proof-of-work and event-admission behavior from the declared upstream release.
- [ ] **NET-10** Validate relay directory updates, provenance, caching, and offline fallback data.
- [ ] **NET-11** Handle relay rejection, rate limits, malformed messages, disconnections, and partial relay availability.
- [ ] **NET-12** Test internet loss/recovery and transition between mesh and internet delivery without duplicate conversations.
- [ ] **NET-13** Document relay trust, visible recipient/channel metadata, and third-party retention limits.

## 10. Tor and network privacy

**Milestone:** M5. **Exit condition:** Protected traffic remains protected through startup, failure, recovery, and shutdown.

- [ ] **TOR-01** Build or integrate the Tor implementation for macOS, Windows, and Linux with dependency/license review.
- [ ] **TOR-02** Preserve the verified Apple artifact provenance or replace it with reproducible build evidence.
- [ ] **TOR-03** Define one explicit default network privacy policy and the behavior of each user-selectable mode.
- [ ] **TOR-04** Implement bootstrap progress, connection health, failure messages, and retry behavior.
- [ ] **TOR-05** Keep Tor-enabled traffic fail-closed; never silently fall back to direct connections.
- [ ] **TOR-06** Audit all outbound requests, including relay directories, updates, media, and diagnostics, against that policy.
- [ ] **TOR-07** Test DNS/proxy bypass, connection reuse across mode changes, and startup/shutdown races.
- [ ] **TOR-08** Keep Tor state, cache retention, and panic-wipe behavior consistent with the documented policy.
- [ ] **TOR-09** Measure Tor's actual installed, startup, memory, and background-network cost per platform.
- [ ] **TOR-10** Document unavailable censorship-resistance features and evaluate bridges/transports separately from baseline parity.

## 11. Secure storage and identity lifecycle

**Milestone:** M4 / M5. **Exit condition:** Identity and retained state survive intended restarts and are removed or protected as documented.

- [ ] **STORE-01** Define a versioned inventory of identity, trust, favorites, blocks, drafts, archives, queues, media, and settings.
- [ ] **STORE-02** Use macOS Keychain with BitChat Desktop-specific service/access-group identifiers.
- [ ] **STORE-03** Implement Windows per-user protected key storage and verify profile/lock behavior.
- [ ] **STORE-04** Implement the selected Linux secret-service/keyring integration and behavior when it is locked or absent.
- [ ] **STORE-05** Avoid silently writing private keys to unprotected files when secure storage is unavailable.
- [ ] **STORE-06** Separate BitChat Desktop state from an installed Bitchat client and test side-by-side operation.
- [ ] **STORE-07** Choose transactional on-disk storage and atomic schema migration/recovery behavior.
- [ ] **STORE-08** Preserve exactly which records are encrypted, temporary, durable, expired, or excluded from backup.
- [ ] **STORE-09** Implement retention limits, bounded caches, and cleanup scheduling.
- [ ] **STORE-10** Define reset/recovery behavior for missing keys, corrupted databases, and partial migration.
- [ ] **STORE-11** Define identity export/import only if included in the release scope; otherwise omit the UI and document its absence.
- [ ] **STORE-12** Test multi-instance access, concurrent writes, permissions, low disk space, and unexpected termination.

## 12. Native macOS client

**Milestone:** M1 / M4 / M6. **Exit condition:** A native BitChat Desktop app builds, launches, interoperates, and fits normal macOS behavior.

- [ ] **MAC-01** Finish the clean-checkout Release build and resolve all remaining relocation/build issues.
- [ ] **MAC-02** Verify Apple Silicon and any Intel architecture included in the published support matrix.
- [ ] **MAC-03** Complete BitChat Desktop naming, icons, About information, menu items, help links, and upstream attribution.
- [ ] **MAC-04** Audit entitlements, Bluetooth/location/microphone permissions, sandbox settings, and signing configuration.
- [ ] **MAC-05** Verify app-group and Keychain isolation from upstream Bitchat.
- [ ] **MAC-06** Implement/test native menus, keyboard shortcuts, window sizing, focus, and multi-window policy.
- [ ] **MAC-07** Verify notifications, notification actions, app activation, and background/minimized behavior.
- [ ] **MAC-08** Verify file dialogs, drag/drop, clipboard handling, and media permission flows.
- [ ] **MAC-09** Integrate the Rust boundary in tested stages and compare behavior before removing Swift equivalents.
- [ ] **MAC-10** Run VoiceOver, text scaling, appearance, contrast, and input-method checks.
- [ ] **MAC-11** Test clean install, upgrade, sleep/resume, lock/unlock, relaunch, and uninstall/data-retention behavior.

## 13. Native Windows client

**Milestone:** M4 / M6. **Exit condition:** The Windows app runs on the declared hardware/OS matrix with native interaction and correct transport behavior.

- [ ] **WIN-01** Create the actual Win32 application target and a repeatable Windows build.
- [ ] **WIN-02** Define ownership of the message loop, core runtime, UI state, and background tasks.
- [ ] **WIN-03** Build the conversation list, message view, composer, peer list, and settings interface.
- [ ] **WIN-04** Integrate the shared core, Windows Bluetooth adapter, and secure storage.
- [ ] **WIN-05** Resolve package identity and Bluetooth capability requirements for the chosen distribution format.
- [ ] **WIN-06** Implement native file dialogs, clipboard, links, notifications, and notification activation.
- [ ] **WIN-07** Handle high DPI, multiple monitors, scaling changes, dark/high-contrast themes, and system fonts.
- [ ] **WIN-08** Implement keyboard navigation, Unicode/IME input, selection, and screen-reader support.
- [ ] **WIN-09** Define minimize/tray/close behavior and avoid an unexpected permanent background process.
- [ ] **WIN-10** Test sleep/resume, user-session lock, network changes, multiple adapters, and driver failure.
- [ ] **WIN-11** Build/test each declared CPU architecture with explicit runtime prerequisites.
- [ ] **WIN-12** Verify clean install, upgrade, uninstall, and signing/reputation behavior on Windows.

## 14. Native Linux client

**Milestone:** M4 / M6. **Exit condition:** The Linux app works in the supported distro/desktop combinations with explicit dependencies and permissions.

- [ ] **LIN-01** Create the actual GTK4 application target and repeatable Linux build.
- [ ] **LIN-02** Define GTK main-loop integration and shared-core task/callback ownership.
- [ ] **LIN-03** Build the conversation list, message view, composer, peer list, and settings interface.
- [ ] **LIN-04** Integrate the shared core, Linux Bluetooth adapter, and secure storage.
- [ ] **LIN-05** Define GTK, Bluetooth service, libc, and other minimum dependency versions.
- [ ] **LIN-06** Verify desktop-user Bluetooth permissions without requiring the app to run as root.
- [ ] **LIN-07** Implement native/portal file dialogs, clipboard, notifications, and external-link behavior.
- [ ] **LIN-08** Handle Wayland/X11 as declared in the support matrix, scaling, themes, and multiple monitors.
- [ ] **LIN-09** Test accessibility with Orca, keyboard-only use, text scaling, Unicode, and IME.
- [ ] **LIN-10** Handle unavailable/locked keyrings, headless sessions, Bluetooth-daemon restarts, and suspend/resume.
- [ ] **LIN-11** Test each chosen distro/desktop/architecture on a clean system.
- [ ] **LIN-12** Verify sandbox/portal/system-bus permissions for any chosen self-contained package.
- [ ] **LIN-13** Document installation dependencies and clear troubleshooting steps for unsupported configurations.

## 15. Shared desktop conversation experience

**Milestone:** M4 / M6. **Exit condition:** The three native interfaces expose consistent messaging semantics and understandable connection states.

- [ ] **UX-01** Design first launch, local identity/nickname setup, and permission explanations without requiring a BitChat Desktop account.
- [ ] **UX-02** Distinguish nearby mesh, internet channels, direct conversations, groups, and unavailable transports.
- [ ] **UX-03** Show nearby peers, verified identity, reachability, and supported capabilities without overstating trust.
- [ ] **UX-04** Implement public and private text compose/send flows with correct destination selection.
- [ ] **UX-05** Preserve independent drafts across conversations and transport switches.
- [ ] **UX-06** Implement message ordering, timestamps, selection/copy, unread state, and native text behavior.
- [ ] **UX-07** Display pending, delivered, read, retry, expired, and failed states accessibly.
- [ ] **UX-08** Implement favorites, blocking/unblocking, verification fingerprints/QR, and supported vouch flows.
- [ ] **UX-09** Match the supported command set and provide discoverable native controls/help for essential actions.
- [ ] **UX-10** Treat payment/token text as untrusted content; port supported formatting without adding wallet custody or automatic spending.
- [ ] **UX-11** Confirm supported deep links and avoid ambiguous OS-level ownership between BitChat Desktop and Bitchat.
- [ ] **UX-12** Handle empty state, no peers, denied permission, unavailable adapters, Tor startup, and disconnected relays.
- [ ] **UX-13** Use virtualized/bounded message and peer views for large histories.
- [ ] **UX-14** Implement navigation, focus restoration, keyboard shortcuts, and accessible control labels on all platforms.
- [ ] **UX-15** Verify RTL text, Unicode spoofing display, emoji, IME composition, and long/untrusted nicknames.
- [ ] **UX-16** Provide language selection and maintain localization parity for user-facing states and errors.
- [ ] **UX-17** Make notification previews and lock-screen content user-controlled.
- [ ] **UX-18** Document history clearing versus identity reset/panic wipe so their effects are distinguishable.

## 16. Groups, verification, and trust features

**Milestone:** M6. **Exit condition:** The advertised group/trust features match upstream semantics across compatible clients.

- [ ] **GROUP-01** Implement group creation, invitation, acceptance, membership display, and leaving.
- [ ] **GROUP-02** Match group identifiers, key distribution, message encryption, and sender authentication.
- [ ] **GROUP-03** Implement administrator/removal/rekey rules and document access to past versus future messages.
- [ ] **GROUP-04** Reject malformed, unauthorized, stale, duplicate, and conflicting membership updates.
- [ ] **GROUP-05** Persist and restore group state with protected keys and migration rules.
- [ ] **GROUP-06** Match supported vouch/verification attestations, expiry, identity binding, and revocation behavior.
- [ ] **GROUP-07** Test group and trust changes across offline peers, reconnects, and mixed supported client versions.
- [ ] **GROUP-08** Advertise group/trust capabilities only after the corresponding behavior is verified.

## 17. Images, files, voice notes, and live voice

**Milestone:** M6. **Exit condition:** Media works within explicit limits without bypassing encryption, consent, or resource controls.

- [ ] **MEDIA-01** Implement compatible public file/image/audio packet metadata and transfer framing.
- [ ] **MEDIA-02** Implement private-media encryption, session binding, identifiers, and authenticated metadata.
- [ ] **MEDIA-03** Implement negotiated legacy handling only when explicitly permitted and visibly described; never silently downgrade private content.
- [ ] **MEDIA-04** Match correlated private-media delivery/read receipts and bounded retry behavior.
- [ ] **MEDIA-05** Require the intended receiver consent before persisting or opening incoming content.
- [ ] **MEDIA-06** Validate MIME/type, filename, size, paths, and resource limits; prevent traversal and unsafe automatic execution.
- [ ] **MEDIA-07** Implement bounded temporary storage, cancellation, progress, timeout, resume/retry policy, and cleanup.
- [ ] **MEDIA-08** Implement image selection/preview and decoding with bounds on decompressed resource use.
- [ ] **MEDIA-09** Implement voice-note capture, encoding, playback, device selection, and microphone permission handling.
- [ ] **MEDIA-10** Implement compatible push-to-talk formats, sequencing, jitter/loss handling, and ephemeral retention where supported.
- [ ] **MEDIA-11** Handle audio-device changes, interruption, contention, and mute/permission changes.
- [ ] **MEDIA-12** Keep media traffic fair to text, handshakes, and receipts on constrained BLE links.
- [ ] **MEDIA-13** Verify public/private media and voice paths against the selected iOS/Android clients.
- [ ] **MEDIA-14** Measure codec/dependency size and use native facilities where they preserve the required format.

## 18. Location channels, boards, and nearby notes

**Milestone:** M6. **Exit condition:** Location-related features reveal only the intended information and interoperate within the declared scope.

- [ ] **GEO-01** Implement geohash/channel encoding, precision, labels, subscriptions, and switching.
- [ ] **GEO-02** Offer manual location/channel selection where automatic location is unavailable or declined.
- [ ] **GEO-03** Request location access only for an explained user action and avoid disclosing exact coordinates inadvertently.
- [ ] **GEO-04** Match geohash presence, participants, expiry, and rate limits.
- [ ] **GEO-05** Implement channel bookmarks/favorites and restore the intended selection after restart.
- [ ] **GEO-06** Implement signed board posts, tombstones, expiry, ordering, and validation where shipping upstream.
- [ ] **GEO-07** Implement nearby-note storage, display, settings, and alerts where included in the support matrix.
- [ ] **GEO-08** Handle malicious location labels, conflicting posts, stale updates, and flooding.
- [ ] **GEO-09** Verify that location and board traffic use the chosen internet/privacy path.
- [ ] **GEO-10** Test channel/board behavior across platforms and the declared mobile peers.

## 19. Gateway, bridge, and mesh diagnostics

**Milestone:** M6. **Exit condition:** Optional bridge/gateway roles are explicit and cannot create loops or misleading trust.

- [ ] **BRIDGE-01** Verify which gateway/bridge/diagnostic paths are active in the selected upstream clients.
- [ ] **BRIDGE-02** Implement carrier validation, origin authentication, destination constraints, and bounded payloads.
- [ ] **BRIDGE-03** Implement mesh-to-Nostr/geohash bridge directionality, deduplication, expiry, and loop suppression.
- [ ] **BRIDGE-04** Implement supported bridge courier/drop flows with their actual trust and retention rules.
- [ ] **BRIDGE-05** Expose role enablement, channel scope, resource cost, and privacy effects to the user.
- [ ] **BRIDGE-06** Implement compatible ping/pong, trace, and topology views without confusing relay observations with trusted identity.
- [ ] **BRIDGE-07** Test multiple gateways/bridges, intermittent internet, relayed duplicates, and unsupported peers.
- [ ] **BRIDGE-08** Advertise these capabilities only in builds and modes where the corresponding behavior is enabled and tested.

## 20. Privacy, abuse resistance, and reset behavior

**Milestone:** M5 / M7. **Exit condition:** The documented privacy model survives malformed traffic, local failures, and user-triggered reset.

- [ ] **PRIV-01** Write a threat model covering malicious peers/relays, passive radio observation, local access, metadata, and compromised endpoints.
- [ ] **PRIV-02** Document public versus private content and the forward-secrecy properties of every delivery path.
- [ ] **PRIV-03** Rate-limit announcements, connection attempts, handshakes, sync requests, routing, couriers, and media.
- [ ] **PRIV-04** Bound memory, CPU work, disk use, peer tables, history, and queues under adversarial traffic.
- [ ] **PRIV-05** Validate untrusted content before rendering, opening links/files, decoding media, or allocating large buffers.
- [ ] **PRIV-06** Make blocking apply consistently across direct delivery, couriers, Nostr, media, groups, and notifications as supported.
- [ ] **PRIV-07** Define panic wipe across keys, sessions, favorites, queues, archives, media, drafts, Tor state, and diagnostics.
- [ ] **PRIV-08** Cancel/invalidate in-flight callbacks and writes so erased state cannot be restored after panic wipe.
- [ ] **PRIV-09** Test interrupted/partial wipe and expose recoverable failure rather than reporting false success.
- [ ] **PRIV-10** Explain limits of deletion on SSDs, backups, OS caches, other peers, and third-party relays.
- [ ] **PRIV-11** Audit clipboard, notifications, screenshots/previews, logs, crash reports, temporary files, and saved attachments.
- [ ] **PRIV-12** Ensure diagnostics are local/redacted by default and any export is deliberate and reviewable.
- [ ] **PRIV-13** Complete an independent security review of the protocol port and FFI before stable-release security claims.
- [ ] **PRIV-14** Publish a scoped security policy and distinguish verified findings, known limitations, and audit coverage.

## 21. Compatibility and quality verification

**Milestone:** M3–M7. **Exit condition:** Claims are backed by a repeatable matrix with reproducible evidence and actionable failures.

- [ ] **QA-01** Maintain deterministic unit tests for codecs, state transitions, expiry, retries, routing, and persistence.
- [ ] **QA-02** Maintain independent crypto and wire fixtures with source revision, generator/provenance, and hashes.
- [ ] **QA-03** Run negative vectors for bad signatures/tags, replay, malformed frames, unsupported versions, and resource exhaustion.
- [ ] **QA-04** Test each desktop client against Bitchat iOS and Android in both send and receive directions.
- [ ] **QA-05** Test macOS↔Windows, macOS↔Linux, and Windows↔Linux for every claimed transport.
- [ ] **QA-06** Test mixed multi-hop mesh paths, partitions, moving couriers, and partition rejoining.
- [ ] **QA-07** Test BLE and internet delivery racing, duplication, out-of-order traffic, and receipt correlation.
- [ ] **QA-08** Test loss, latency, clock skew, network switching, and unstable links with deterministic fault injection.
- [ ] **QA-09** Test installation and startup on clean machines, including absent optional services or runtimes.
- [ ] **QA-10** Test upgrade, schema migration, rollback compatibility, uninstall, reset, and side-by-side Bitchat installation.
- [ ] **QA-11** Test application kill, crash, disk full, storage corruption, permissions changes, and resume after suspension.
- [ ] **QA-12** Run FFI ownership/lifetime tests and applicable memory/concurrency sanitizers.
- [ ] **QA-13** Run parser/state-machine fuzzing and retain regression corpora.
- [ ] **QA-14** Test long-running background/minimized operation and repeated connect/disconnect cycles.
- [ ] **QA-15** Run native accessibility and keyboard/input-method checks on all three platforms.
- [ ] **QA-16** Record OS/CPU/hardware/driver/client versions with each physical-device result.
- [ ] **QA-17** Track flaky tests and environmental limitations without silently weakening acceptance assertions.
- [ ] **QA-18** Keep release qualification separate from scaffold compilation and UI smoke tests.

## 22. Application size, startup, and resource budgets

**Milestone:** M4–M7. **Exit condition:** Published measurements represent feature-matched usable installations, and regressions are gated.

- [ ] **SIZE-01** Create reproducible measurement scripts for each platform and architecture.
- [ ] **SIZE-02** Measure compressed download, installed application files, missing prerequisites, and working data separately.
- [ ] **SIZE-03** Record build flags, toolchain versions, signing state, architectures, features, and dependency versions.
- [ ] **SIZE-04** Measure a complete baseline after required messaging, crypto, native adapters, and Tor are included.
- [ ] **SIZE-05** Set explicit per-platform footprint budgets from those baselines and record the rationale.
- [ ] **SIZE-06** Set startup, first-peer discovery, message-latency, idle CPU/RAM, and background-network budgets with test conditions.
- [ ] **SIZE-07** Measure idle, active mesh, internet, Tor bootstrap, media transfer, and large-history scenarios.
- [ ] **SIZE-08** Keep debug symbols and developer tools out of user packages while retaining symbols for debugging.
- [ ] **SIZE-09** Compare architecture-specific and universal builds and publish the distinction.
- [ ] **SIZE-10** Reduce duplicate assets, fonts, codecs, runtimes, TLS/crypto stacks, and unused features where correctness permits.
- [ ] **SIZE-11** Compare size optimization, LTO, stripping, and dependency feature settings using actual release outputs.
- [ ] **SIZE-12** Check GTK/runtime prerequisite cost on clean Linux/Windows installations instead of counting only the executable.
- [ ] **SIZE-13** Add release-size and resource regression reporting with an explicit review threshold.
- [ ] **SIZE-14** Verify that optimizations preserve interoperability, accessibility, useful diagnostics, and privacy behavior.

## 23. Build automation and contributor workflow

**Milestone:** M1–M7. **Exit condition:** A clean checkout can be checked and built without private workstation assumptions.

- [ ] **CI-01** Pin or document tested Rust, Swift/Xcode, Windows SDK, and Linux toolchain versions.
- [ ] **CI-02** Keep lockfiles and reproducible dependency-resolution instructions current.
- [ ] **CI-03** Build real native application targets on their target OS once implemented.
- [ ] **CI-04** Add application-level tests alongside the existing scaffold/package checks.
- [ ] **CI-05** Validate packaged resource paths, fixture paths, and generated native bindings in CI.
- [ ] **CI-06** Separate public untrusted-PR checks from signing/release jobs and their credentials.
- [ ] **CI-07** Minimize workflow permissions and review externally sourced build steps/dependency changes.
- [ ] **CI-08** Preserve logs, test reports, symbols, and build metadata needed to diagnose failed jobs.
- [ ] **CI-09** Add release artifact production only after the corresponding app passes qualification.
- [ ] **CI-10** Document local commands and troubleshooting that work without this laptop's company hooks or signing identity.
- [ ] **CI-11** Add contributor guidelines for protocol changes, native UI changes, performance evidence, and upstream synchronization.
- [ ] **CI-12** Keep CI status and platform support claims consistent with actual test coverage.

## 24. Packaging, distribution, and updates

**Milestone:** M7. **Exit condition:** Users can install, verify, update, and remove a supported release with predictable data handling.

- [ ] **REL-01** Select primary distribution formats per OS and document why each is supported.
- [ ] **REL-02** Produce macOS app archives/installers for the declared architectures.
- [ ] **REL-03** Produce Windows packages with declared native runtime and package-identity requirements.
- [ ] **REL-04** Produce Linux distro packages and separately evaluate any self-contained format.
- [ ] **REL-05** Configure signing/notarization where required and keep private signing material out of the repository.
- [ ] **REL-06** Verify package identity, icons, versions, permissions, file/deep-link associations, and uninstall metadata.
- [ ] **REL-07** Inventory bundled/transitive dependencies, licenses, source requirements, and notices.
- [ ] **REL-08** Produce dependency manifests/SBOMs, checksums, source commit references, and build provenance.
- [ ] **REL-09** Write clean-machine installation, verification, upgrade, and removal instructions.
- [ ] **REL-10** Define update channels and authenticate update metadata and artifacts before installation.
- [ ] **REL-11** Make updates atomic/recoverable and compatible with schema/data migration rules.
- [ ] **REL-12** Respect OS/package-manager update ownership and the selected network privacy policy.
- [ ] **REL-13** Test interrupted downloads/updates, invalid signatures, stale versions, rollback, and low disk space.
- [ ] **REL-14** Decide release retention and revocation procedures for compromised/broken artifacts.
- [ ] **REL-15** Publish accurate release notes, supported-peer versions, measured sizes, and known limitations.
- [ ] **REL-16** Verify downloaded user artifacts, not only build-tree executables.

## 25. Open-source maintenance and upstream tracking

**Milestone:** M1 / ongoing. **Exit condition:** The project remains attributable, maintainable, and honest about compatibility.

- [ ] **OPEN-01** Maintain this roadmap, platform matrix, architecture decisions, and public project status.
- [ ] **OPEN-02** Create issue/PR templates for bugs, compatibility failures, hardware reports, and feature proposals.
- [ ] **OPEN-03** Define maintainer review, release ownership, and handling of external contributions.
- [ ] **OPEN-04** Document how to report security issues privately and how disclosures are coordinated.
- [ ] **OPEN-05** Review upstream changes regularly and record the last reviewed/applied revision.
- [ ] **OPEN-06** Prioritize upstream security fixes and protocol changes over cosmetic divergence.
- [ ] **OPEN-07** Reconcile relocated source carefully and preserve local branding/storage identity.
- [ ] **OPEN-08** Add conformance evidence whenever the supported upstream/client version changes.
- [ ] **OPEN-09** Track dependency maintenance, vulnerabilities, licenses, and end-of-support dates.
- [ ] **OPEN-10** Keep an explicit changelog of platform limitations, deprecated features, and removed compatibility.
- [ ] **OPEN-11** Define support expectations, bug triage, release cadence, and stale-platform retirement criteria.

## 26. Stable-release acceptance checklist

**Milestone:** M7. **Exit condition:** Every claimed platform/feature has evidence; unresolved blockers prevent a stable label.

- [ ] **SHIP-01** Close the agreed release scope or explicitly reduce it with a documented support-matrix change.
- [ ] **SHIP-02** Pass complete native Release builds and the required application/core test suites.
- [ ] **SHIP-03** Pass the declared cross-client and cross-platform physical-device interoperability matrix.
- [ ] **SHIP-04** Verify public/private messaging, delivery status, trust, retention, and failure behavior on each supported platform.
- [ ] **SHIP-05** Verify Tor/privacy mode behavior and prevent silent direct-network fallback.
- [ ] **SHIP-06** Complete security review and resolve release-blocking findings.
- [ ] **SHIP-07** Meet documented accessibility, size, startup, resource, and reliability budgets.
- [ ] **SHIP-08** Pass clean install, upgrade, uninstall, reset, and crash-recovery qualification.
- [ ] **SHIP-09** Verify signatures, checksums, dependency notices, provenance, and downloadable artifacts.
- [ ] **SHIP-10** Publish user documentation, support boundaries, compatibility versions, and known issues.
- [ ] **SHIP-11** Tag the exact release source and retain the matching evidence/artifacts.
- [ ] **SHIP-12** Define hotfix, rollback, compromised-key, and incident-response procedures before broad distribution.

## 27. Explicitly deferred or separate decisions

**Milestone:** After baseline / separate scope. **Exit condition:** These are not silently included in the first stable-release promise.

- [ ] **LATER-01** Evaluate new upstream capabilities after confirming they are shipping and interoperable.
- [ ] **LATER-02** Evaluate rotating peer-ID/announce-v2 behavior as a separate privacy/protocol change; do not enable it solely because a codec exists.
- [ ] **LATER-03** Evaluate reserved/non-shipping capabilities such as Wi-Fi bulk transfer or alternate Noise replacement only with an approved compatibility plan.
- [ ] **LATER-04** Evaluate Tor bridges/pluggable transports with separate size, dependency, and privacy measurements.
- [ ] **LATER-05** Evaluate additional architectures, distributions, packaging formats, or app stores after the primary matrix is reliable.
- [ ] **LATER-06** Evaluate identity backup/migration and multi-device behavior as explicit security/product features.
- [ ] **LATER-07** Evaluate optional, consent-based diagnostics only if local reports prove insufficient.
- [ ] **LATER-08** Reconsider a shared UI framework only if measured native-maintenance cost changes the agreed priorities.
- [ ] **LATER-09** Consider BitChat Desktop mobile/browser clients, custom servers, wallets, or new networks only as separately scoped projects.

## Evidence and source index

- [Project charter](VISION-AND-MISSION.md), [architecture](ARCHITECTURE.md), [upstream provenance](UPSTREAM.md), and [initial local validation](SETUP-VALIDATION.md).
- [Size and framework research](DESKTOP-RESEARCH.md): UI baselines and the difference between package size and complete installation footprint.
- [Wire message types](../apps/macos/localPackages/BitFoundation/Sources/BitFoundation/MessageType.swift), [capability assignments](../apps/macos/localPackages/BitFoundation/Sources/BitFoundation/PeerCapabilities.swift), and [locally advertised capabilities](../apps/macos/bitchat/Protocols/PeerCapabilities+Local.swift). These must be read together with runtime dispatch; constants alone do not establish support.
- [Upstream whitepaper](../WHITEPAPER.md), [BLE architecture](BLE-ARCHITECTURE-V3.md), [source routing](SOURCE_ROUTING.md), and [private-media migration](PRIVATE-MEDIA-MIGRATION.md).
- [Custom Nostr envelopes](../apps/macos/bitchat/Nostr/NostrProtocol.swift), [embedded packet format](../apps/macos/bitchat/Nostr/NostrEmbeddedBitChat.swift), and [interop fixture manifest](../tests/interop/manifest.json).
- [Tor integration](TOR-INTEGRATION.md), [Arti provenance](ARTI-BINARY-PROVENANCE.md), [radio detectability](SERVICE-UUID-DETECTABILITY.md), and [peer-ID rotation proposal](PEER-ID-ROTATION.md).

Inherited documents can describe proposals, platform-specific behavior, or older assumptions. Resolve conflicts against pinned code, independent fixtures, and tested clients; record the result in the compatibility matrix.
