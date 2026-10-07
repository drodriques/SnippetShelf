# Changelog

## 0.1.0 — 2026-10-07

Initial source release of SnippetShelf for macOS.

- Create, edit, delete, and favorite saved text snippets in the desktop app.
- Organize snippets with hierarchical tags and filter by parent or child tags.
- Search titles and content with an expanding toolbar search field and Command-F.
- Copy saved snippets from the desktop or menu bar, including nested tag groups.
- Copy local Network, Device, and Date & Time values using built-in System actions;
  favorite actions and refresh values when copying.
- Store snippets, tags, and favorites locally, preserving supported older save
  formats with backups when they are first saved in the current format.
- Keep the search icon and expanded field right-aligned when resizing columns.
- Keep the fullscreen header aligned with its column backgrounds and support
  Control–Command–F while search is active.
- Provide sidebar and fullscreen commands in the View menu.
- Include an app icon and matching monochrome menu bar icon.

Requires macOS 13 or later and Xcode with Swift 5.9 or later to build from source.
See [README.md](README.md) for installation and usage. Packaged builds are locally
ad hoc signed; they are not Developer ID signed or notarized. This release does
not include hosted binaries, an automatic updater, or cloud sync. Saved data is
plain-text JSON; quit the app before backing up or restoring it.

Licensed under GPL-3.0-only. See [LICENSE](LICENSE).
