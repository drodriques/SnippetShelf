# Changelog

## Unreleased

- Add a security policy with private vulnerability reporting instructions.

## 0.1.0-beta.1 — In preparation

- Reuse the list cache after saving to avoid a repeated sort, and keep passive
  window observation out of pointer hit testing.

- Simplify the README around installation and a quick start; retain detailed
  public usage, settings and backup instructions in a linked user guide.

- Match app action icons to the sidebar’s secondary symbol color, retaining
  purple selection/focus highlights; give search its full circular click target.

- Give compact sidebar buttons full rectangular hit areas around their icons.
- Anchor the compact tag popover to the right of its ellipsis button and use
  explicit navigation actions that dismiss it, including when reselecting a tag.

- Use inset purple selection backgrounds with rounded corners across navigation,
  snippet/System lists and word history, preserving full-row hit targets.

- Add a README Light/Dark overview captured from the actual app, with a fictional
  sample library and reusable source images.

- Fix empty-tag navigation and show a quiet association message without inline
  creation actions; offer Clear Search when no snippets match a query.

- Replace the single-page Settings tab selector with a purple General heading
  so native selected-tab blue no longer conflicts with the app palette.

- Use an ellipsis icon for the compact sidebar’s tag menu.

- Use shared transparent inline section labels for built-in System groups and
  word lists, removing remaining contrasting native header strips.

- Add saved Auto/Light/Dark theme selection in General settings; Auto follows
  macOS and the selected theme applies to the library, Settings and Help.

- Use an icon-inspired purple accent for app highlights and blend the Current
  word row into the shared panel surface. Apply the same accent to editor sheets
  and match text-area scrollbar tracks to their input surfaces.

- Blend scrollbar tracks into their surrounding surfaces and draw native thumbs
  in neutral gray at 25% opacity throughout lists, details, editors, Settings and Help.

- Use the native compact unified toolbar to reduce the top bar height while
  retaining aligned window controls and navigation.

- Default new background-translucency preferences to Opaque; retain the optional
  slider and preserve existing saved preferences.

- Let both native dividers resize all three panels, preserving practical minimum
  widths, toolbar alignment and the compact rail; match sidebar symbol colors
  between expanded and compact navigation.

- Unify the library panels inside an inset rounded container, with matching
  one-point dividers and a full-width status row.
- Add a compact sidebar rail with accessible navigation and a tag-tree popover;
  move Settings to the upper-right app menu, retaining the standard menu/shortcut.
- Add adjustable native background translucency with an opaque option and support
  for macOS Reduce Transparency. Text and controls remain opaque.
- Keep panel headers below the native toolbar so fullscreen controls cannot cover
  search or creation actions; constrain resizing using native split-view items.
- Remove late-inserted native Emoji & Symbols duplicates when menus change.
- Keep native background/measurement views out of pointer hit testing so
  translucency changes cannot block Search, creation actions or the sidebar toggle.

- Add validated semantic release metadata, beta version display in About, explicit
  architecture builds, and drag-to-Applications DMG packaging.
- Document DMG installation, per-release platform support, and manual updates.
- Strip debug/linker source paths from packaged executables and reject residual
  checkout paths before signing.

- Separate search, native text input and window support from library navigation.
- Inject persistence and System providers, make startup loading explicit, and add
  application-state regression tests for failures, selection, history and shutdown.
- Isolate native menu compatibility by command selectors and make main-queue
  notification delivery and cleanup explicit for strict concurrency checking.

- Limit periodic System previews to visible, active System/Favorites views,
  coalesce preview requests, and use a single fresh snapshot per copy.
- Cache navigation counts, hierarchy paths, active-list filtering and word history;
  avoid sorting collections merely to count them.
- Coalesce Edit-command validation and restrict native menu cleanup to menu opening.
- Parse saved snippet files once per read, retaining exact migration backups and
  refusing invalid/newer files. Run file I/O on serial actors, serialize edits
  across saves, and finish pending writes before quitting.

- Put top-level tag creation beside the Tags heading, with independent collapse
  and add controls.
- Reuse past words as new current occurrences after confirmation while retaining
  the original history entry and archiving the previous current word.

- Add one current Word of the Day with a definition, editable/deletable history,
  search, copying, and independent local storage.
- Show the current word beside the menu-bar icon and provide General settings
  to hide the word label or the whole menu-bar item; preferences persist.

- Reopen the library from the Dock after closing its window, restore it when
  minimized, and bring it forward without creating duplicate library windows.

- Align native window buttons and the sidebar toggle in the compact toolbar;
  keep group titles, search and creation actions in the panel headers below it.

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

### Initial functionality

Initial beta of SnippetShelf for macOS.

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

Requires macOS 13 or later. Each published release identifies its supported
architectures and binary signing/notarization status. There is no automatic
updater or cloud sync. Saved data is plain-text JSON; quit the app before backing
up or restoring it. See [README.md](README.md) for installation and usage.

Licensed under GPL-3.0-only. See [LICENSE](LICENSE).
