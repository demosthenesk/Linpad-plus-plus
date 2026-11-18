# Changelog

## 1.0.2 — 2026-11-18
* Fix: the zoom level (View → Zoom, Ctrl+Mouse Wheel) was reset every time Linpad++ was closed.
  Each view's zoom is now saved on exit and restored on the next start, as in Notepad++.

## 1.0.1 — 2026-10-31
* Fix: Settings → Preferences → Dark Mode (Light / Dark / Follow system) had no visible effect on
  the editor. The choice now applies immediately and switches the editor theme too, like Notepad++:
  light mode uses stylers.xml, dark mode uses DarkModeDefault, and a theme picked in the Style
  Configurator is remembered separately for each mode.
* "Follow system" now reads the desktop setting (XDG portal / GNOME color-scheme / GTK or KDE theme
  name) and follows changes while Linpad++ is running.
* Linpad++ always uses the Fusion widget style with its own light and dark palettes, so the host's
  GTK/KDE theme can no longer override the chosen mode.
* Menu entries that name the editor itself now say Linpad++ ("About Linpad++",
  "Read-Only in Linpad++", "Update Linpad++"), in every UI language.

## 1.0.0 — 2026-10-31
First release: Linux clone of Notepad++ 8.9.6.2 x64.

* Full menu bar recovered from RT_MENU 1500 (File … ?), with command IDs, and the 368 default
  shortcuts from the exe's key table; all 94 Notepad++ localizations apply to the menus.
* Two views (move/clone), tab bar with saved/unsaved/read-only/monitoring icons, tab colours,
  pinning, MRU Ctrl+Tab; Document List, Function List, Folder as Workspace, Document Map,
  Project Panels 1–3, Character Panel, Clipboard History, Search Results.
* 90+ languages with Notepad++'s keywords and styles; 22 themes; Style Configurator; dark mode.
* Find / Replace / Find in Files / Find in Projects / Mark (Normal, Extended, Regex),
  incremental search, smart highlighting, Style Token 1–5, bookmarks and bookmark line ops,
  change history, tag matching, clickable links.
* Line operations and sorting (incl. column-key sort), case conversions, comment toggling,
  blank operations, EOL conversion, paste special, multi-select, column editor, redact.
* Encodings: ANSI (locale code page), UTF-8 (±BOM), UTF-16 LE/BE, 46 character sets; convert/reinterpret.
* Auto-completion and parameter hints from Notepad++'s API files; auto-indent; auto-close.
* Macros (record/playback/save/run N times), Run dialog with $(VARIABLES), MD5/SHA digests,
  MIME Tools, Converter, NppExport (HTML/RTF) built in.
* Sessions in Notepad++ session.xml format, periodic snapshot backup of unsaved documents,
  file change detection, Monitoring (tail -f), single instance with argument forwarding,
  Notepad++ command-line options.
