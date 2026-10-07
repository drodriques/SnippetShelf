# SnippetShelf app icon

`SnippetShelf-original.png` is the full-resolution selected artwork: flat ivory
overlapping code cards on a purple tile, with matching lavender braces and text
lines and a purple outline separating the cards.
It was created with OpenAI image generation and selected on October 7, 2026.
The original PNG is preserved here without resizing or recompression.

`../../scripts/build-icon.sh` uses the macOS tools `sips` and `iconutil` to create
all standard 16–1024 pixel icon representations from this source. The app build
packages the resulting `SnippetShelf.icns` in its Resources folder. No additional
package or downloaded tool is required.

To replace the icon, update the source PNG and rebuild the app:

```sh
./scripts/build-app.sh --install
```

The menu bar uses a monochrome 18-point rendering of the overlapping cards and braces in
`Sources/SnippetShelf/MenuBarIcon.swift`. It is drawn as a native template image
so macOS adapts its color to light and dark backgrounds. Two rear text lines
and extra spacing between the braces keep the small symbol readable. The colored app tile
is omitted to keep the menu bar symbol readable at its small size.
