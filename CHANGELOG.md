# Changelog

## Unreleased

- Restore horizontal alignment of native window buttons, the sidebar toggle,
  group title, search, and creation actions without a spare title-bar row.

- Bound the snippet column to 360–640 points and protect a 360-point detail column.
- Keep the title and search in the snippet header, with explicit responsive
  ellipsis actions that switch at the same width when shrinking and expanding.
- Enable Edit commands only for applicable text input and add the native emoji
  picker with Control–Command–Space, without additional dependencies.
- Remove Bring All to Front while retaining the library window command.
- Add offline Help based on the public usage, tags, System, and storage guidance.

- Keep collapsed and expanded search inside the snippet column when native toolbar
  spacing changes or the window and column dividers are resized.
- Match the sidebar separator, snippet separator, and status-bar border.
- Restore visible fullscreen search and action buttons with current Xcode builds,
  and match the fullscreen sidebar background to the snippet column.
- Preserve compact circular New Snippet and Manage Tags buttons.

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
