# Contributing to SnippetShelf

Bug reports and pull requests are welcome. For a bug report, include your macOS
version, steps to reproduce, and expected and actual behavior. Use invented
snippet text; do not include private saved data.

## License

Contributions to SnippetShelf are provided under the project's GPL-3.0-only
license. Preserve existing copyright notices and identify any third-party code
and its license when proposing a change. See [LICENSE](LICENSE) for the full terms.

## Development

1. Install Xcode and select its developer tools.
2. Open `Package.swift` in Xcode, select the **SnippetShelf** scheme and **My Mac**,
   then Run, or use the build commands below.
3. Keep model and persistence changes in `SnippetCore`, and UI changes in
   `SnippetShelf`.
4. Run `swift test` and `./scripts/build-app.sh`.
5. Complete the manual checks below for any UI changes.

Use `./scripts/build-app.sh --install` to update the copy in Applications after
quitting all running SnippetShelf copies. Successful installation removes the
app bundle from `dist` to avoid duplicate launcher entries; failed installation
keeps the build for retrying. The default build command retains the app in
`dist` and does not install anything, so development builds stay within
the repository.

### App packaging and installation

The build script creates a release executable, packages it with application
metadata, and ad hoc signs `dist/SnippetShelf.app`. Prefer this bundle for manual
UI checks so macOS sees the application's metadata.

The install step verifies a staged copy before replacing the installed app and
refuses to overwrite an unrelated application or symbolic link. If installation
fails, the generated bundle remains in `dist` for retrying or manual installation.
The build is not Developer ID signed or notarized.

## Manual checks

- Launch the app bundle; create a snippet with multiline text and Unicode.
- Edit its title and content; save and restart the app; verify both persist.
- Search by part of a title and by content.
- Copy from the desktop and menu bar; paste into TextEdit and compare the text.
- Favorite a snippet and verify it moves to the top of both lists.
- Cancel an edit and verify the saved snippet is unchanged.
- Cancel deletion, then confirm deletion and verify it persists after restart.
- Close the desktop window; verify the menu bar remains available.
- Choose New Snippet from the menu bar with the desktop window closed.
- Quit from the menu bar and verify the app exits.

## Hierarchical tag checks

- Create `Development/Git` and `Work/Emails/Follow-ups` using New Sub-tag.
- Assign one snippet to both leaf tags, and another to a parent and its child.
- Select a root: verify descendants appear and each snippet appears once.
- Verify All Snippets, Favorites, Untagged, and scoped search.
- Rename and move a tag; verify full paths and assignments update immediately.
- Verify tag names reject empty values, `/`, and line breaks. Sibling names must
  be unique ignoring case and accents; matching names in different branches are
  allowed.
- Verify a new snippet under a tag starts with that tag selected, and one under
  Favorites starts as a favorite.
- Verify the parent picker excludes the edited tag and all its descendants.
- Cancel deleting a branch; verify it stays intact. Confirm deletion of disposable
  test tags; verify snippets and unrelated assignments remain.
- Expand menu bar tag submenus and All in This Group; copy and paste a nested
  snippet. Verify favorites remain at the top.
- Restart the app and verify the hierarchy and assignments persist.
- With an isolated copy of a 0.1 save file, verify migration and the exact legacy
  backup. Never test migration by replacing a user's actual data.

## Built-in System checks

- Open each System group and verify labels, values, and copy buttons.
- Verify Network distinguishes interfaces and IPv4/IPv6. Where multiple addresses
  are present, verify copying includes one address per line.
- Copy a date/time action, wait, then copy again; verify it resolves a fresh value.
- Favorite a built-in; verify it appears in desktop and menu bar Favorites, and
  persists after restart. Verify it does not appear in All Snippets or Untagged.
- Verify system details have no edit or delete controls.
- Search by a built-in name or displayed value in the selected group.
- Verify disconnected favorites remain visible with a reason and do not replace
  the clipboard. Test network changes only on a machine where changing connections
  is appropriate; unit tests use fake network sources instead.
- Verify menu bar System actions work without any saved snippets.
- Test version-1 migration with a disposable file copy and confirm its exact
  `snippets.v1-backup.json` backup.

The persistence tests use temporary directories, never your real snippet file.
Changes should preserve existing saved data or document an explicit migration.

### Detail layout regression check

At both the default window size and the smallest allowed size, select built-in
Network, Device, and Date & Time items. Confirm Copy and Refresh remain entirely
above the status bar and clickable, including when an explanation wraps. Also
check a saved snippet's Copy, Edit, and Delete controls. The status bar occupies
its own row below the navigation columns rather than overlapping their content.
Verify its full-width top divider matches the native vertical separator in color
and thickness, without obscuring the status text or detail actions.

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

## Automated tests

```sh
swift test
./scripts/build-app.sh
```

Tests cover Unicode and multiline persistence, updates, deletion, corrupt files,
search, favorite ordering, legacy migration, nested filtering, multiple tags,
renaming, moving, subtree deletion, invalid moves, version validation, fresh
system values, disconnected favorites, multiple network addresses, date/time
zones, and built-in favorite persistence. Manual UI verification steps are listed above.

### Group header and sidebar appearance

At default and minimum window sizes, verify the selected group title and search
appear once in the top toolbar, with search immediately to the title's right.
Drag the list/detail divider narrower and wider with search both collapsed and
expanded; search must remain right-aligned within the snippet column.
There must be no second header row or extra horizontal separator above the list.
Verify the search field blends into the toolbar background and its padded text
and controls remain visible. Check a long nested tag
path, typing and clearing a query, switching groups, and Command-F focus. Ensure
filtering and empty results stay scoped to the selected group. Keep New Snippet
and Manage Tags in the top toolbar. In light and dark appearances, verify New Tag
shares the sidebar background, has a subtle hover highlight, and remains usable.
The sidebar keeps its native list background without a custom material or color.
Verify the title row has no contrasting toolbar strip and the list/detail divider
extends to the top of the window. The title row follows the selected group.

### Expanding toolbar search

Verify the collapsed search circle is 36 points across, matching the New Snippet
button, and the expanded field retains the same 36-point height.
Verify the search icon expands on click or Command-F and focuses the text field.
Typing filters immediately; a nonempty query stays visible after focus leaves.
An empty field collapses on focus loss. Escape clears a query first, then closes
an empty field. Clearing with the clear button keeps focus. The title, column
widths, and divider must stay fixed during expansion/collapse. With Reduce Motion,
the same state changes occur without animation. Verify light/dark focus borders.

### Fullscreen header

Enter and leave fullscreen with Control–Command–F, with search both collapsed and
active. Verify the header inherits its column background in light/dark appearance,
starts at the top without a spare toolbar row, and keeps one group title with
36-point search and action controls. Toggle the sidebar both ways, open/cancel
New Snippet and New Tag, switch groups, and check the detail actions and footer.
Move the pointer to the top edge to reveal native window controls. Check that
leaving fullscreen restores the original toolbar, colors, column dividers, and
window size, preserving an active query. Repeat the transition with Reduce Motion.

When testing column resizing, also maximize/restore the window and enter/exit
fullscreen with search collapsed and expanded. Confirm that the header stays
aligned and the app remains stable throughout each transition.

Verify the View menu opens and its sidebar/fullscreen commands work in both
windowed and fullscreen modes. Window → Minimize is available outside fullscreen.
