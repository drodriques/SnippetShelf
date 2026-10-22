# SnippetShelf

A native macOS snippet manager with a desktop editor and a menu bar for quick
copying. Create, edit, delete, search, and favorite snippets, organize them with
hierarchical tags, or copy live system information. Copy saved text to
the clipboard from either interface.

SnippetShelf is built with SwiftUI and AppKit, stores your collection locally,
and has no third-party dependencies. You can build and run it on your own Mac
without publishing it in the Mac App Store or buying a developer membership.

## Supported platform

SnippetShelf targets **macOS 13 Ventura or later**. Release notes identify the
verified Mac architectures for each download:

- **Apple Silicon**: Macs with M-series chips (`arm64`).
- **Intel**: Macs with Intel processors (`x86_64`), when listed as supported.
- A **universal** DMG contains both architectures. Architecture availability does
  not imply that every Mac model or macOS version has been tested.

## Install using a DMG

1. Open [GitHub Releases](https://github.com/drodriques/SnippetShelf/releases).
   For beta testing, choose a release marked **Pre-release** and review its
   supported platforms and known issues.
2. Under **Assets**, download the appropriate **`.dmg`** file. GitHub's **Source
   code** ZIP/tar files are for developers, not application installers.
3. Open the DMG and drag **SnippetShelf** onto **Applications**.
4. Eject the DMG, then launch **SnippetShelf** from **Applications**. Confirm the
   normal macOS downloaded-app prompt if shown.

To update, quit SnippetShelf and repeat these steps with the newer DMG, replacing
the app in Applications. Your saved snippets and words remain in Application
Support. There is no automatic updater yet.

For building from source, see [CONTRIBUTING.md](CONTRIBUTING.md).

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
6. Close the desktop window to keep the menu bar available. Click the Dock icon
   to reopen the window or restore it if minimized. You can also choose
   **Open SnippetShelf…** or **New Snippet…** from the menu bar to return to the editor.
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

## Word of the Day

Select **Word of the Day** in the sidebar, then click **+** (or **⌘N** while
viewing words). Enter a word and definition and choose **Save Word**. Both fields
are required. One word is current at a time, and it stays current until you
replace or delete it; nothing changes automatically at midnight.

- **New Word** makes the new entry current and keeps the previous entry in
  **History**, newest added first. You can add another word at any time.
- **Edit…** changes the selected current or past entry without creating a duplicate
  or changing which word is current. Its original added date is preserved.
- Select a past word and choose **Use as Current…** beside Edit or from its
  right-click menu, then confirm **Use as Current**. This creates a new occurrence
  dated today, archives the previous current word, and keeps the original past
  entry and its date unchanged. **Cancel** leaves all words unchanged.
- Select a current or past word and choose **Delete…** to remove it after confirmation.
  Deleting the current word clears the menu-bar word and keeps history; a past
  word is not promoted automatically.
- Search matches words and definitions. **Copy Word** copies the selected word.

The current word appears beside the menu-bar icon. Long words are shortened
there; open the menu to copy the word, copy it with its definition, edit it, add
a new word, or open history. The menu shows a short definition preview; select
**Word of the Day & History…** for the full text. Words are entered manually and
stored locally; there is no dictionary service or daily download.

## General settings

Choose **Settings…** at the bottom of the sidebar, **SnippetShelf → Settings…**,
or press **⌘,** and open **General**.

- **Show current word beside the menu-bar icon** controls the word label only.
  The current word and history remain available inside the menu and desktop.
- **Show SnippetShelf in the menu bar** controls the entire menu-bar item: turning
  it off hides both the icon and word. The word-label setting is disabled while
  the entire item is hidden, and its previous preference is remembered.

These preferences persist after quitting. To restore a hidden menu-bar item,
click SnippetShelf in the Dock and open Settings. Hiding it does not quit the app.

## Organize with hierarchical tags

The desktop has three columns: groups, snippets, and the selected snippet.
**All Snippets**, **Favorites**, and **Untagged** stay available at the top of
the sidebar. Search applies to the selected group and matches title or content.

- Click **+** immediately after the **Tags** label to create a top-level tag,
  or choose **Manage Tags → New Top-level Tag…**. The plus remains available
  when Tags is collapsed. Use the chevron to the left of **Tags** to expand or
  collapse the list; individual tags retain their own sub-tag disclosure arrows.
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
Previews refresh every 30 seconds while the main window is visible and active
and shows a System group or Favorites containing System actions, or immediately
with **Refresh**. Copying always reads a fresh value. Unavailable items cannot replace
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

The current word and word history are stored separately in:

```text
~/Library/Application Support/SnippetShelf/words.json
```

Quit SnippetShelf before copying these files to make a backup or replacing them
with earlier backups. Restoring a file replaces that collection. Back up both
files to preserve snippets and words together. Menu-bar preferences are stored
in macOS app preferences rather than these JSON files.
Uninstalling the app leaves your saved data in place.

These files are plain-text JSON and are not encrypted. SnippetShelf does not provide
cloud sync. Copied text goes to the macOS clipboard and may be accessed by
clipboard tools or shared through Universal Clipboard, according to your settings.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for developer setup, project structure,
build and test commands, and manual checks.

## License

Copyright (c) 2026 SnippetShelf contributors.

Licensed under the [GNU General Public License, version 3 only](LICENSE)
(`GPL-3.0-only`). See [LICENSE](LICENSE) for the full terms.
