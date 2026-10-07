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

Launch **SnippetShelf** from **Applications**. Quit all running copies before
installing. Run the same command after future changes to update the installed
app; your saved snippets and tags stay in Application Support.

If you cannot write to Applications, build with `./scripts/build-app.sh`, then
copy `dist/SnippetShelf.app` to Applications using Finder. After confirming it
opens, remove the copy from `dist` to avoid duplicate launcher entries.

The packaged app is ad hoc signed for local use; it is not Developer ID signed
or notarized.

If macOS blocks a trusted source build because it came from a downloaded ZIP,
review **System Settings → Privacy & Security** for the **Open Anyway** option.
Do not disable Gatekeeper globally.

## Use

1. Open **SnippetShelf**. Its desktop window and code-cards icon in the menu bar
   give you access to the same collection.
2. Click **+** or press **⌘N** to create a snippet. Enter a title and content,
   optionally mark it as a favorite, then click **Save Snippet**.
3. Select a snippet to view it. Click **Edit…** to change it or **Delete…** to
   remove it. Deletion asks for confirmation; **Cancel** discards an edit.
4. Click the search icon beside the group name or press **⌘F** to expand search
   and match titles or content. **Escape** clears a query; press it again to close
   an empty search field. Favorites appear first,
   followed by the most recently saved snippets.
5. Click **Copy Snippet**, press **⇧⌘C** while viewing a snippet, or choose its
   title from the menu bar. Paste into your destination with **⌘V**.
6. Close the desktop window to keep the menu bar available. Use
   **Open SnippetShelf…** or **New Snippet…** in that menu to return to the editor.
7. Choose **Quit SnippetShelf** or press **⌘Q** to quit completely.

Use **Control–Command–F** to enter or leave fullscreen, including while search
is active. In fullscreen, move the pointer to the top edge to reveal macOS window
controls. Leave fullscreen before using **Window → Minimize** or **⌘M**.
The **View** menu provides sidebar and fullscreen controls.
Escape clears or closes search first.

The snippet column can be resized from 360 to 640 points. The detail column keeps
at least 360 points and uses the remaining space. Search stays in the snippet
header. When the detail column is narrower than 420 points, its action buttons
become a **…** menu with **New Snippet…** and **New Top-level Tag…**. The separate
buttons return when that column reaches 420 points again. Use a tag's right-click
menu for nested-tag actions when the compact menu is shown.

The **Edit** menu follows the focused text field, including search and tag names.
To insert emoji, focus a field and choose **Edit → Emoji & Symbols**, or press
**Control–Command–Space**. Undo, Cut, Copy, Paste, and Select All are enabled only
when the focused text field supports the action. **Window → SnippetShelf** brings
the library window back; **Help → SnippetShelf Help** opens local guidance that
works offline.

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
- Right-click a tag and choose **Rename or Move…** to change its name or parent.
  Its snippet assignments and sub-tags stay attached.
- **Delete Tag…** removes the tag and its sub-tags after confirmation. Your
  snippets are kept; those without any remaining tags appear under **Untagged**.

The menu bar includes nested tag menus. Choose **All in This Group** to access
snippets throughout a branch, or select a snippet to copy its content.

## Built-in System actions

The sidebar's **System** section contains **Network**, **Device**, and
**Date & Time**. Select a group, select an item to preview its value, then use
the labeled copy button or **⇧⌘C**. Built-ins have no edit or delete controls.

| Group | Built-ins |
| --- | --- |
| Network | Active non-loopback interface addresses, labeled by connection and IPv4/IPv6 |
| Device | Computer name and macOS version |
| Date & Time | Local date (`YYYY-MM-DD`), local date/time with a zone label, UTC ISO 8601 timestamp |

Network shows addresses for each active connection. These are read from local
interfaces; the app does not look up your public IP address.

Use the star to add a built-in to **Favorites** alongside your saved snippets.
Previews refresh automatically while the view is active, or immediately with
**Refresh**. Copying always reads a fresh value. Unavailable items cannot replace
your clipboard contents.

The menu bar offers the same actions under **System**, with favorites at the top.
Search matches built-in names and values within the selected group. Built-ins
are separate from **All Snippets**, **Untagged**, and your tag groups.

All built-ins run locally without internet requests or third-party dependencies.
Only favorite choices are saved; live system values are not stored.

## Storage and backups

Your snippets, tags, and favorite choices are stored locally at:

```text
~/Library/Application Support/SnippetShelf/snippets.json
```

Quit SnippetShelf before copying this file to make a backup or replacing it with
an earlier backup. Restoring a backup replaces your current collection.
Uninstalling the app leaves your saved data in place.

The file is plain-text JSON and is not encrypted. SnippetShelf does not provide
cloud sync. Copied text goes to the macOS clipboard and may be accessed by
clipboard tools or shared through Universal Clipboard, according to your settings.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for developer setup, project structure,
build and test commands, and manual checks.

## License

Copyright (c) 2026 SnippetShelf contributors.

Licensed under the [GNU General Public License, version 3 only](LICENSE)
(`GPL-3.0-only`). See [LICENSE](LICENSE) for the full terms.
