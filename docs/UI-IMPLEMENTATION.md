# Desktop UI implementation checklist

The approved gallery contains 37 screens and component states. All 37 have a native macOS presentation or an existing native system presentation wired into the desktop shell. This checklist separates UI availability from real-device qualification. Existing Bitchat workflows are reused; this change does not implement a new messaging protocol.

The desktop shell adds a persistent, collapsible sidebar, inline direct/group conversations, person search, explicit channel selection, native settings shortcuts, and the three study palettes. Bubble / Terminal remains an independent persistent preference. Liquid Glass is retained for existing preferences. The gallery’s separate settings previews are sections of the actual Settings page.

| Done | Screen / state | macOS entry and implementation |
|---|---|---|
| ✓ | Mesh chat | Sidebar → #mesh; public timeline and composer |
| ✓ | Location conversation | Sidebar channel or Browse channels → selected geohash |
| ✓ | Private conversation | Select a person; inline conversation with encryption and delivery indicators |
| ✓ | Attachments & voice messages | Conversation attachments, file progress and voice playback; both message layouts |
| ✓ | Voice recording | Composer microphone; recording, cancel and send controls |
| ✓ | Live voice | Settings → live voice; composer and incoming live badge |
| ✓ | Nearby people | Sidebar → All people; reachable, favorite, blocked and verification states |
| ✓ | Across the bridge | All people → Across the bridge; distinct from radio roster |
| ✓ | Recent conversations | Sidebar and All people → recent conversations, including offline people |
| ✓ | Groups | Sidebar and All people → groups; creation and management through existing commands |
| ✓ | Location-channel people | Location channel → All people; geohash people and private conversations |
| ✓ | Peer fingerprint & alias | Person context menu or private header → fingerprint, verification and alias |
| ✓ | My verification code | Sidebar → Verify identity → My QR |
| ✓ | Scan or paste verification | Verify identity → Scan; native camera preview and paste fallback |
| ✓ | Location channels | Browse channels; permissions, scope, bookmarks and teleport controls |
| ✓ | Share channel invitation | Location header / channel action → share; precision warning before native sharing |
| ✓ | Mesh board | Sidebar → Notices → mesh tab; post, urgency and expiry controls |
| ✓ | Location notes | Notices → geo tab; notes, relay loading, permission, retry and error states |
| ✓ | Choose an image | Composer image control → themed sheet and native NSOpenPanel |
| ✓ | Image preview & export | Image attachment → preview → native save panel; themed preview header |
| ✓ | Command suggestions | Type / in the composer; context-aware existing command suggestions |
| ✓ | Mesh topology | Sidebar → Mesh topology; observed graph, empty state and refresh |
| ✓ | Connectivity & relays | Settings → bridge, gateway, location, Tor and custom relay controls |
| ✓ | Notification privacy & reset | Settings → notification previews and separated danger zone |
| ✓ | Appearance & language | Settings → Terminal / Native Light / Graphite / retained Liquid Glass, Bubble / Terminal and language |
| ✓ | About & help | Sidebar brand → Info; help, symbols and independent upstream attribution |
| ✓ | No nearby peers | Empty mesh timeline; real Bluetooth state gates radar and discovery hints |
| ✓ | Bluetooth unavailable | Persistent banner and native alert; distinct off, denied and unsupported states |
| ✓ | Tor connectivity blocked | Persistent connectivity banner; internet pause with mesh behavior preserved |
| ✓ | Confirm panic wipe | Settings danger zone or triple-click brand → destructive confirmation |
| ✓ | Incomplete wipe | Root or private-pane persistent incomplete-wipe banner |
| ✓ | Clear conversation | /clear → existing native confirmation; only current conversation cleared |
| ✓ | Message & participant actions | Message / person context menus; existing mention, private chat, favorite, block and copy actions |
| ✓ | Legacy media warning | Existing explicit consent dialog before sending legacy unencrypted private media |
| ✓ | Screenshot privacy notice | Settings → Privacy → Screenshots & privacy; iOS capture notice remains inherited |
| ✓ | Microphone / recording error | Existing microphone/recording alert; denied permission opens system settings |
| ✓ | Review shared content | Sidebar → Review clipboard → destination review → use in composer or cancel |

## Limits and remaining work

- Windows and Linux interfaces remain scaffolds. This implementation is the macOS client; cross-platform UI parity is still pending.
- Native file, save, share, context-menu and confirmation dialogs use macOS controls. Their layout follows the operating system rather than duplicating the gallery’s illustrative cards.
- There is no macOS Share extension. Review clipboard supplies the desktop shared-content review workflow, with bounded text, an explicit destination, and confirmation before replacing a draft.
- macOS does not provide the inherited iOS screenshot notification. The privacy notice is available in Settings; automatic screenshot detection is not implemented.
- Group creation/management remains command driven, as specified in the screen inventory. No separate group editor was proposed.
- New desktop copy has English fallback. Full translation coverage for the new labels remains pending.
- Real Bluetooth exchanges, camera permission/scan, microphone capture/live voice, relay connectivity, destructive wipes, and OS sharing require device testing. Render and coordinator tests do not establish their end-to-end behavior.

## Validation

The scoped native test run covers view rendering, all three study palettes at a proposed 800 × 580 minimum size, inline private/public selection, draft isolation, message formatting, and desktop import confirmation. Local visual render artifacts use only a mock peer roster. No real message was sent, recording started, or wipe executed during validation.

Build, signature, test count and bundle size are recorded in [SETUP-VALIDATION.md](SETUP-VALIDATION.md). Design PNGs and gallery files are not bundled in the app.
