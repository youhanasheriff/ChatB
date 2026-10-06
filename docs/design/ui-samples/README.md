# BitChat Desktop UI samples

Three visual directions cover 37 existing screens, sheets, component states, and dialogs: 111 combinations in the [interactive gallery](index.html). Open `index.html` directly in a browser; no installation, external fonts, network services, or build step is needed.

- **Terminal:** compact monospaced text, restrained green, and dark native surfaces. Closest to the current Bitchat-derived interface and the recommended starting point.
- **Native Light:** light surfaces, quiet emerald accents, and clear native control hierarchy.
- **Graphite:** slate panels, silver text, and restrained cyan navigation accents.

The gallery supports screen search, previous/next navigation, theme switching, sample message composition, and illustrative toggles. Destructive buttons only show a sample notification. Camera, microphone, radio, keys, files, and real messages are never accessed.

## Generated overview boards

The built-in image-generation tool created these exploratory six-screen overview boards:

- [Terminal](terminal.png)
- [Native Light](native-light.png)
- [Graphite](graphite.png)

The complete original prompts are in [image-prompts.json](image-prompts.json). Generated overview labels and controls are illustrative; the source-mapped gallery is the more precise screen-by-screen proposal. The overviews do not establish feature support, routing defaults, radio range, or security behavior.

## Coverage and implementation

[screen-inventory.json](screen-inventory.json) maps the 37 entries to existing Swift views. Reusable views such as the message composer, delivery indicators, voice controls, and media items appear in their host conversation. Settings sections are shown individually for review, though the current app groups them in one sheet. System file/share dialogs are represented by a sample native selection or confirmation surface. The inherited share-import review is included for completeness; its iOS share extension is outside the desktop product scope.

These samples propose desktop navigation and styling. They do not implement any change in the running native application. The gallery's three directions are alternatives; they are not a promise to ship three new themes. A selected direction should be implemented with native controls, system fonts, and vector icons to preserve the small application footprint. Generated PNGs belong only to design documentation and should not be bundled in the app.

## Validation

All 111 screen/direction combinations rendered in the collaborative browser without errors or horizontal overflow at a 1440-pixel desktop viewport. Screen search, visual-direction switching, fingerprint navigation, and safely escaped sample message composition were exercised. JavaScript syntax and local gallery links were checked. Full functionality, camera/radio interactions, and platform parity remain native-app validation tasks.
