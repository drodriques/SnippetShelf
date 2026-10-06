# SnippetShelf

A native macOS snippet manager with a desktop editor and a menu bar for quick
copying. Create, edit, delete, search, and favorite snippets, organize them with
hierarchical tags, or copy live system information. Copy saved text to
the clipboard from either interface.

SnippetShelf is built with SwiftUI and AppKit, stores your collection locally,
and has no third-party dependencies. You can build and run it on your own Mac
without publishing it in the Mac App Store or buying a developer membership.

## Requirements

- macOS 13 Ventura or later.
- Xcode 15 or later, with Swift 5.9 or later, for building from source.
- Select Xcode's tools under **Xcode → Settings → Locations → Command Line Tools**.

This initial version is installed by building from source. There is no hosted
binary release or automatic updater yet.

## Install from source

Download the repository ZIP from GitHub and extract it, or clone the repository.
Open Terminal in the extracted repository folder and run:

```sh
./scripts/build-app.sh --install
```

Launch **SnippetShelf** from **Applications**. The script builds a release
executable, packages it as a locally signed Mac application, and installs it at
`/Applications/SnippetShelf.app`. Quit all running copies before installing.
Run the same command after future changes to replace the installed app; your
saved snippets and tags stay in Application Support. After a successful
installation, the script removes `dist/SnippetShelf.app` so the launcher does
not have a second app copy to discover. If installation fails, the build stays
in `dist` for retrying or manual installation.

Without `--install`, the script only builds `dist/SnippetShelf.app`, which is
useful for development:

```sh
./scripts/build-app.sh
```

If you cannot write to Applications, copy `dist/SnippetShelf.app` there using
Finder, then remove the copy from `dist` after confirming the installed app
opens correctly. The install step verifies a staged copy before replacing an existing
SnippetShelf app, and refuses to overwrite an unrelated app or symbolic link.

To open the code in Xcode:

```sh
open Package.swift
```

Select the **SnippetShelf** scheme and **My Mac**, then Run. For normal use,
prefer the packaged `.app` so macOS sees its application metadata.

### Local builds and public releases

The script uses ad hoc signing for local use. This is not Developer ID signing
or Apple notarization. A public binary release should be signed with Developer
ID and notarized so it opens normally on other Macs. That process requires
Apple Developer Program membership, but an App Store listing is optional.
See [Apple's distribution guide](https://developer.apple.com/macos/distribution/).

If macOS blocks a trusted source build because it came from a downloaded ZIP,
review **System Settings → Privacy & Security** for the **Open Anyway** option.
Do not disable Gatekeeper globally.

## Use

1. Open **SnippetShelf**. Its desktop window and shelf icon in the menu bar
   give you access to the same collection.
2. Click **+** or press **⌘N** to create a snippet. Enter a title and content,
   optionally mark it as a favorite, then click **Save Snippet**.
3. Select a snippet to view it. Click **Edit…** to change it or **Delete…** to
   remove it. Deletion asks for confirmation; **Cancel** discards an edit.
4. Use the search field to match titles or content. Favorites appear first,
   followed by the most recently saved snippets.
5. Click **Copy Snippet**, press **⇧⌘C** while viewing a snippet, or choose its
   title from the menu bar. Paste into your destination with **⌘V**.
6. Close the desktop window to keep the menu bar available. Use
   **Open SnippetShelf…** or **New Snippet…** in that menu to return to the editor.
7. Choose **Quit SnippetShelf** or press **⌘Q** to quit completely.

Copying puts plain text on the clipboard; it does not automatically paste into
another app. No Accessibility permission is needed for this workflow.

## Organize with hierarchical tags

The desktop has three columns: groups, snippets, and the selected snippet.
**All Snippets**, **Favorites**, and **Untagged** stay available at the top of
the sidebar. Search applies to the selected group and matches title or content.

- Click **New Tag…** in the sidebar, or **Manage Tags → New Top-level Tag…**.
- To nest a tag, select its parent and choose **Manage Tags → New Sub-tag…**,
  or right-click a tag and choose **New Sub-tag…**.
- Expand a tag's disclosure arrow to see its sub-tags. Selecting a parent shows
  every snippet assigned anywhere beneath it, with no duplicate rows.
- In the snippet editor, check any number of tags. Full paths such as
  `Work/Emails/Follow-ups` distinguish similarly named tags. A snippet can belong
  to several branches without duplicating its content.
- A new snippet created while viewing a tag starts with that tag selected.
  A new snippet created under Favorites starts as a favorite.
- Right-click a tag and choose **Rename or Move…**, or use **Manage Tags**.
  Edit its name or choose another parent; **Top Level** moves it to the root.
  Existing snippet assignments and the tag's sub-tags stay attached.
- **Delete Tag…** asks for confirmation and removes that tag and all its
  sub-tags. It keeps every snippet and every assignment outside the deleted
  branch. Snippets with no remaining assignments appear under **Untagged**.

Names must be nonempty, cannot contain `/` or line breaks, and must be unique
under the same parent (ignoring case and accents). The same name can be used
in different branches. Moving a tag inside itself or a sub-tag is prevented.

The menu bar shows favorites first, followed by **All Snippets**, **Untagged**,
and nested tag submenus. Each tag menu includes directly assigned snippets and
its child groups. **All in This Group** includes every nested snippet, matching
the desktop's parent-group behavior. Selecting a snippet copies its content.

## Built-in System actions

The sidebar's **System** section contains **Network**, **Device**, and
**Date & Time**. Select a group, select an item to preview its value, then use
the labeled copy button or **⇧⌘C**. Built-ins have no edit or delete controls.

| Group | Built-ins |
| --- | --- |
| Network | Active non-loopback interface addresses, labeled by connection and IPv4/IPv6 |
| Device | Computer name and macOS version |
| Date & Time | Local date (`YYYY-MM-DD`), local date/time with a zone label, UTC ISO 8601 timestamp |

Wi-Fi, Ethernet, tunnels, and other active interfaces appear separately. A
connection with multiple addresses of the same family copies them one per line.
IPv6 link-local values may include a scope suffix such as `%en0`; it identifies
the connection used by that address. These are addresses read from local
interfaces, not a public-IP lookup; some IPv6 interface addresses can be globally
routable. The app does not choose a single "main" connection for you.

Use the star in an item's detail pane, or its context menu, to add it to
**Favorites** alongside favorite saved snippets. Network favorites follow the
connection and address family when its addresses change. A disconnected favorite
remains visible as unavailable and can still be removed from Favorites.

Previews refresh on opening a group, activating the desktop window, and every
30 seconds while that view is active. **Refresh** updates them immediately.
Copying reads the value again, so dates, times, and addresses are current at the
moment of copying. If a value is unavailable, copying is disabled or reports
the reason without replacing the clipboard.

The menu bar offers **System → Network / Device / Date & Time**, with a single
click to copy an action. System favorites appear at the top with saved favorites.
Search filters built-in names and their displayed values within the selected
group. **All Snippets**, **Untagged**, and tag groups contain only your saved
snippets.

All built-ins run locally using Foundation, Darwin, and SystemConfiguration
provided by macOS. No third-party package, internet request, or public-IP service
is used. Only your favorite-action choices are saved; live system values are
not written to the snippet file.

## Storage and backups

Snippets are stored as plain-text JSON at:

```text
~/Library/Application Support/SnippetShelf/snippets.json
```

Quit the app before backing up or restoring that file. Back up the whole
SnippetShelf folder if preferred. App upgrades preserve this file. Uninstalling
the `.app` leaves your data in place; delete the data folder separately if you
want to remove the collection.

Snippets are not encrypted, and copied text goes to the system clipboard.
There is no app-managed cloud sync or network service. macOS clipboard tools
and Universal Clipboard may access or transfer copied text according to your
system settings.

The file contains a versioned library with snippets, tags, assignments, and
built-in favorite choices.
The original untagged snippet-array format loads automatically. On the first
successful save, the app writes the new format and preserves the original as
`snippets.legacy-backup.json` in the same folder. Existing snippets keep their
IDs, titles, contents, favorites, and dates. Older app versions cannot read the
new library format; restore the legacy backup only if you intentionally revert,
since it does not contain subsequent edits or tags.

Libraries from version 0.2 also load automatically. Before their first upgraded
save, the app keeps an exact copy as `snippets.v1-backup.json`. The new library
format is version 2; earlier app versions reject it instead of discarding built-in
favorites. Reverting to a backup loses changes made after that backup.

Writes replace the saved file atomically. If loading fails, the app preserves
the existing file and disables saves. Restore a valid backup and select
**Retry Loading**. Failed saves retain the editor draft for another attempt.

## Project structure

```text
Package.swift                     Swift package and macOS deployment target
Sources/SnippetCore/               Models, tags, system providers, filtering, migration, JSON repository
Sources/SnippetShelf/              Shared state, desktop UI, editor, menu, clipboard
Tests/SnippetCoreTests/            Persistence and search tests
Assets/AppIcon/                    Original icon artwork and notes
Resources/Info.plist               Application metadata
scripts/build-icon.sh              macOS icon generation from the original PNG
scripts/build-app.sh               Release build, .app packaging, optional install
.github/workflows/ci.yml.disabled  Build/test workflow, disabled by filename
```

A single shared store feeds both interfaces. The repository has no UI dependency,
and changes are published only after a successful save.

The app icon source and replacement instructions are in
[Assets/AppIcon/README.md](Assets/AppIcon/README.md). App builds generate the
macOS icon using built-in tools; no extra dependencies are needed.

## Test

```sh
swift test
./scripts/build-app.sh
```

Tests cover Unicode and multiline persistence, updates, deletion, corrupt files,
search, favorite ordering, legacy migration, nested filtering, multiple tags,
renaming, moving, subtree deletion, invalid moves, version validation, fresh
system values, disconnected favorites, multiple network addresses, date/time
zones, and built-in favorite persistence. UI verification steps are in
[CONTRIBUTING.md](CONTRIBUTING.md).

## Publish on GitHub

Create an empty public GitHub repository named `SnippetShelf`. From this folder:

```sh
git init
git add .
git commit -m "Initial SnippetShelf app"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/SnippetShelf.git
git push -u origin main
```

Replace `YOUR-USERNAME` with your GitHub username. Build products and personal
snippets are excluded from the repository. The GitHub Actions workflow is preserved at
`.github/workflows/ci.yml.disabled`, so GitHub does not execute it. Rename it to
`ci.yml` to enable automated builds and tests later. While it is disabled, run
the tests and app build locally before merging or releasing changes.

## Contributing and license

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and manual checks.
SnippetShelf is open source under the [MIT license](LICENSE).
