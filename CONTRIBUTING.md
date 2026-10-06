# Contributing to SnippetShelf

Bug reports and pull requests are welcome. For a bug report, include your macOS
version, steps to reproduce, and expected and actual behavior. Use invented
snippet text; do not include private saved data.

## Development

1. Install Xcode and select its developer tools.
2. Open `Package.swift` in Xcode, or use the commands in the README.
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
- Try a duplicate sibling name; verify the editor shows a validation error.
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
