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
- Click the Dock icon after closing the library; confirm one library window opens.
  Repeat with Help open so another visible window does not prevent reopening.
- Minimize the library, then click the Dock icon; confirm it restores. Click the
  icon repeatedly with the window open; confirm no duplicate library windows.
- Check that the selected group and query survive bringing forward/restoring the
  library, and that menu-bar Open SnippetShelf and New Snippet still work after closing it.
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
Verify its full-width top divider matches both vertical separators in color
and thickness, without obscuring the status text or detail actions.

## Project structure

```text
Package.swift                     Swift package and macOS deployment target
Sources/SnippetCore/               Models, tags, words, system providers, filtering, migration, JSON repositories
Sources/SnippetShelf/              Shared state, desktop UI, editor, menu, clipboard
Tests/SnippetCoreTests/            Models, migrations, hierarchy and storage tests
Tests/SnippetShelfTests/           Stores, loading, save failures, shutdown and native menus
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
zones, and built-in favorite persistence. Word tests cover replacement/archiving,
editing current/history entries, deletion without automatic promotion, search,
Unicode menu labels, persistence, and refusing to overwrite invalid/newer files.
Manual UI verification steps are listed above and in the Word of the Day section.

### Group header and sidebar appearance

At default and minimum window sizes, verify the selected group title and search
appear once in the snippet column header, with search immediately to the title's right.
Drag the list/detail divider narrower and wider with search both collapsed and
expanded; search must remain right-aligned within the snippet column.
There must be no duplicate group header or extra horizontal separator above the list.
Verify the search field blends into the toolbar background and its padded text
and controls remain visible. Check a long nested tag
path, typing and clearing a query, switching groups, and Command-F focus. Ensure
filtering and empty results stay scoped to the selected group. Keep New Snippet
and Manage Tags in the top toolbar. In light and dark appearances, verify Settings
shares the sidebar background, has a subtle hover highlight, and remains usable.
The sidebar keeps its native list background in windowed mode. In fullscreen,
it shares the snippet column's background. Both vertical separators and the
footer border use the same one-point line and appearance-aware color.
Verify the title row has no contrasting toolbar strip and the list/detail divider
extends to the top of the window. The title row follows the selected group.

### Expanding search

Verify the collapsed search circle is 36 points across, matching the New Snippet
button, and the expanded field retains the same 36-point height.
Verify the search icon expands on click or Command-F and focuses the text field.
Typing filters immediately; a nonempty query stays visible after focus leaves.
An empty field collapses on focus loss. Escape clears a query first, then closes
an empty field. Clearing with the clear button keeps focus. The title, column
widths, and divider must stay fixed during expansion/collapse. With Reduce Motion,
the same state changes occur without animation. Verify light/dark focus borders.

### Fullscreen header

In windowed mode, verify close, minimize, and fullscreen buttons share the same
horizontal center line as the sidebar toggle, group title, search, and creation
actions. There must be one sidebar toggle and no native toolbar button over the
group title. Hide the sidebar and confirm its toggle and group title do not
overlap the native buttons. Check native minimize and zoom, then restore the window.

Enter and leave fullscreen with Control–Command–F, with search both collapsed and
active. Verify the header inherits its column background in light/dark appearance,
starts at the top without a spare toolbar row, and keeps one group title with
36-point search and action controls. Verify Search, New Snippet, and Manage Tags
remain visible when built with the current Xcode SDK. Toggle the sidebar both ways, open/cancel
New Snippet and New Tag, switch groups, and check the detail actions and footer.
Move the pointer to the top edge to reveal native window controls. Check that
leaving fullscreen restores the original toolbar, colors, column dividers, and
window size, preserving an active query. Repeat the transition with Reduce Motion.

When testing column resizing, also maximize/restore the window and enter/exit
fullscreen with search collapsed and expanded. Confirm that the header stays
aligned and the app remains stable throughout each transition.

Verify the View menu opens and its sidebar/fullscreen commands work in both
windowed and fullscreen modes. Window → Minimize is available outside fullscreen.

### Responsive header, menus, and help

- Resize the snippet column through its 360–640 point range. The detail column
  must retain at least 360 points; search and the selected group title stay visible.
- Drag the detail column across 420 points in both directions. Below that width,
  the ellipsis menu contains only New Snippet and New Top-level Tag. At or above
  that width, separate action buttons return immediately. Repeat at the minimum
  window size, after maximizing, and in fullscreen in light and dark appearances.
- Outside text input, verify Edit commands are disabled. In search, snippet
  title/content, and tag fields, verify selection-aware Cut/Copy/Delete, Paste,
  Select All, and Undo/Redo. Use disposable text; do not alter saved user data.
- Verify Edit has one Emoji & Symbols entry. Control–Command–Space opens the
  native picker and inserts into the focused field.
- Window retains SnippetShelf and excludes Bring All to Front. Verify restoring
  a minimized or closed library window still works.
- Help opens offline and contains Getting started, hierarchical tags, built-in
  System actions, and storage/backups. Keep HelpView's user guidance synchronized
  with these README sections when their behavior changes.


## Word of the Day and settings checks

- Start with no words; save is disabled until both word and definition are filled.
  Cancel leaves the collection unchanged. Add a word and verify its full definition
  in the desktop, label beside the menu-bar icon, and definition preview in the menu.
- Add a second word. Verify only it is current, the first appears in History, and
  editing either entry changes neither its added date nor the current choice.
- Search words and definitions; copy a word and Word & Definition from the menu
  and compare pasted text. Open menu-bar editing with the library window closed.
- Delete history and current entries separately, including canceling confirmation.
  Deleting the current entry must clear the label without promoting history.
- Quit and relaunch: current word, history, edits, and deletions persist. Verify
  existing snippets/tags are unchanged. Word data lives in words.json alongside
  snippets.json. With an invalid/newer word file, verify Retry Loading Words and
  that mutations are disabled without blocking snippets or overwriting the file.
- Open Settings with ⌘,. Hide/show the word label, then hide the entire menu-bar
  item. Confirm the dependent toggle is disabled. Close the main window; click the
  Dock icon, open Settings, and restore the item. Repeat after quitting/relaunching.
- Check long words, emoji, multiline definitions, history row selection, scrolling,
  minimum window size, and light/dark appearance. With a current word, the toolbar
  + action/⌘N creates a new word only when the Word of the Day page is selected.


### Sidebar Settings, tag creation, and reusing words

- Click Settings at the bottom of the sidebar; confirm the native General settings
  window opens, including when the menu-bar item is hidden. Keep ⌘, working.
- Verify the Tags heading has one chevron on the left and a plus immediately after the Tags label,
  without an additional native disclosure arrow on the right. Collapse/expand
  Tags independently of Library/System and confirm collapse state survives relaunch.
- Use the plus with Tags expanded and collapsed, including an empty tag collection.
  It must open New Top-level Tag, not collapse the list or create a sub-tag. Confirm
  nested tag disclosure and right-click New Sub-tag still work.
- From both a past word's detail and right-click menu, choose Use as Current.
  Cancel must leave words and menu-bar text untouched. Confirm to create exactly
  one new occurrence dated today with the same word/definition; keep the original
  history record and move the previous current word to History. Current words
  must not offer this action.
- Repeat reuse of the same historical record and reuse with no current word.
  Quit/relaunch and verify every occurrence persists. Edit the reused occurrence
  and verify the original remains unchanged. Test the action row at minimum width.


## Resource-efficiency checks

Keep the app native and dependency-free. The app bundle contains the release
executable, icon, license, metadata and signature; development fixtures and
profiling output must not be packaged.

- `LibraryIndex` builds sidebar counts without sorting snippet results, counts
  overlapping ancestor/descendant tag assignments once, and caches the sorted
  hierarchy and paths. Rebuild it only when snippets or tags change. The desktop
  list has one bounded query cache, not an accumulating cache for every keystroke.
  Word history is sorted only when the word collection changes.
- System previews run every 30 seconds only while the library window is visible,
  the app is active, and a System group or Favorites with System actions is shown.
  Coalesce incidental preview requests. Other native menus must not enumerate
  system interfaces. Menu-bar opening requests a preview, and Copy/explicit Refresh
  always bypass throttling. Copy must update previews and clipboard from one fresh
  snapshot. Publish system values only when they actually change.
- Edit-command availability checks may follow native responder updates, but must
  be coalesced. Recursively clean native menu items only when menus open. Verify
  Undo/Redo, selection, paste availability, Emoji & Symbols, and the Window menu
  after changing focus between search, word/snippet/tag editors and the list.
- File parsing, validation, encoding and atomic writes belong to storage actors.
  Serialize the full read/modify/write/publish transaction so overlapping actions
  cannot overwrite an earlier edit with stale state. Dismiss editors only after a
  successful write; preserve drafts on errors and finish pending work before Quit.
  Keep unsupported/corrupt file protection and byte-for-byte migration backups.
- Verify sidebar counts and tag paths after adding, moving and deleting tags;
  compare parent counts with the actual inclusive list. Test word reuse/edit/delete
  and save/relaunch for snippets, words and System favorites. Quit immediately after
  Save and verify the saved collection on relaunch.
- Inspect the release build with Activity Monitor or Instruments using the same
  fixture and interaction sequence before/after changes. Check active System,
  ordinary snippets, Word of the Day, minimized, closed-window and menu-only states.
  Coalesce pending frame measurements while resizing, preserving the latest bounds.
  Short stack samples and RSS snapshots are not proof of battery improvement or
  absence of leaks. Record dataset size, sample duration, app state and metric.

Automated regression coverage includes navigation indexes and serialized storage:
overlapping edits, finishing a pending write despite caller cancellation, corrupt
file protection, migrations, and word history. No performance threshold is asserted
from short or hardware-dependent timing samples.

## App architecture and concurrency

`LibraryView` coordinates navigation and presentation. `LibrarySearchHeader` owns
search expansion/focus, `ToolbarSearchTextField` bridges the native text responder,
and `LibraryWindowSupport` contains window observation, chrome and frame measuring.
Keep native window work out of model and persistence code.

`SnippetStore` and `WordStore` accept `SnippetPersisting`/`WordPersisting` storage
implementations; the snippet store also accepts a `SystemCatalog` backed by an
injected `SystemDataSource`. Tests use in-memory actors and fixed System data,
without reading the user's application-support directory or network interfaces.
Stores initialize in `idle`; the library scene explicitly calls `loadIfNeeded()`.
The `idle`, `loading`, `ready`, and `failed` states determine editing permission.
Retry is explicit, and persistence failures retain the published collection and
selection. A failed save does not turn a successfully loaded library into a failed
load or discard an editor's draft.

Native menu workarounds belong in `NativeMenuCompatibility`: identify system
commands by selectors, not translated display titles. The quick menu is marked
with an identifier after recognizing its own app-owned Open label. Keep that label
centralized if localization is added. `MainActorNotification` confines legacy
NotificationCenter delivery to the main queue and unregisters automatically. Its
small, documented Sendable bridge relies on synchronous main-queue delivery;
do not reuse it to move notification payloads between executors.

Run complete concurrency diagnostics as well as the regular test/build commands:

```sh
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

With a Swift 6 toolchain, also verify language-mode compatibility separately:

```sh
swift test -Xswiftc -swift-version -Xswiftc 6
```

The latter command may emit SwiftPM's language-override warning. It is a diagnostic
check, not a change to the package's declared Swift tools version or deployment
target. App tests cover suspended loading, repeat scene loading, failed-load retry,
failed-save recovery, selection/count updates, cached word reuse/deletion, and
finishing a pending save after caller cancellation. Keep manual search, fullscreen,
Dock and native menu checks because unit tests cannot establish visual correctness.

## Version metadata and DMG packaging

`Resources/Version.json` is the release-version/build source of truth. It uses
Semantic Versioning (for example `0.1.0-beta.1`) and a positive integer build.
After editing it, run:

```sh
./scripts/release-metadata.sh --sync
./scripts/release-metadata.sh --check
./scripts/test-packaging.sh
```

The numeric core is written to `CFBundleShortVersionString`; the build is
`CFBundleVersion`. `SnippetShelfReleaseVersion` preserves the full prerelease
label for About. Build numbers increase for distributed builds; JSON data-file
schema versions are unrelated. A build fails if manifest and plist disagree.

Xcode 15+/Swift 5.9+ is required for source builds. The metadata helper compiles
from the shared Swift version model using the selected Xcode toolchain; there
are no third-party packaging dependencies. The runtime app remains native.

```sh
./scripts/build-app.sh --arch arm64
./scripts/build-app.sh --arch x86_64
./scripts/build-app.sh --arch universal
./scripts/build-dmg.sh dist/SnippetShelf.app dist/SnippetShelf-preview.dmg
```

The default build uses the host architecture. Universal builds preserve separate
Apple Silicon/Intel executables before combining them, verify both Mach-O slices
and their macOS 13.0 minimum target, and package a fresh allowlisted app bundle.
This avoids stale resources and output-location reuse by newer Swift build engines.
Before signing, packaging strips debug/linker symbols containing local source paths
and refuses an executable that still contains the checkout path. Keep any future
debug symbols outside public app/DMG payloads; review artifacts beyond this narrow
path check before publication.
A cross-compiled slice does not establish hardware/minimum-OS compatibility; test
all architectures and OS versions advertised by the release notes.

DMG creation stages only the app and an Applications shortcut, verifies image
integrity, and refuses existing outputs. Mount a local preview read-only to inspect
contents, then eject it. It is not a notarized distribution merely because the
image builds successfully. Official downloads require Developer ID signing,
hardened runtime, secure timestamps, accepted notarization/stapled tickets and
Gatekeeper/downloaded-DMG acceptance. Keep credentials and account-specific
configuration outside this public repository. Published binaries must correspond
to their tagged source and include access to the complete GPL source/build tools.

Verify About shows the full beta label and build, and that normal Dock/menu/search
behavior remains correct. Inspect final image contents, actual architecture slices,
version and license rather than relying on the filename. Source builds installed
with `--install` are ad hoc signed for local use; no developer membership is needed
for those builds. See the README for end-user DMG installation and manual updates.
