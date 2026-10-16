# Pi-Native TUI Style

Visual rules for custom selectors, dialogs, and views, so every extension
matches Pi's `/settings` and `/model`. Use `SelectList`/`SettingsList` when
they can express the UI; apply these rules when a hierarchical or specialized
view needs custom rendering.

- **Theme colors:** draw every colored glyph through the current theme's
  semantic keys with `theme.fg(...)`, and theme-based colorizers for borders
  (`new DynamicBorder((text) => theme.fg("accent", text))`). Never hardcode
  hex, ANSI escape codes, or named terminal colors, so views track the active
  theme.
- **Title:** accent color.
- **Selection:** prefix the selected row with `theme.fg("accent", "→ ")` and
  color both its label and value with `accent`. Never use `selectedBg` or
  another full-row background.
- **Alignment:** reserve the cursor column for every row, then add hierarchy
  indentation after it. Parent and descendant cursors align vertically.
- **Sub-headers:** render section sub-headers (e.g. `INITIAL`, `RUNTIME`) bold
  with `mdHeading`.
- **Hierarchy:** main/group rows use `text`, first-level sub-items and
  unselected values `muted`, deeper sub-items `dim`.
- **Overflow counter:** `dim` `(current/total)`, shown only when some items
  are not visible.
- **Hints:** dim key + muted description, via `keyHint(binding, description)`
  or `rawKeyHint("↑↓", "Navigate")` rather than manual formatting. Join hints
  with ` · `.
- **Description:** a short `muted` explanation directly above the hints, with
  one blank row before and after it.
- **Indentation:** headers, sub-headers, and the `→` cursor sit flush at
  column 0. Indent the description, the `(current/total)` counter, the hint
  row, and preview body content two spaces; reduce the wrap width so wrapped
  lines stay inside the border.
- **Casing:** Title Case for titles, section names, and hint labels
  (`Context Injections`, `Esc Close`); conventional key casing (`PgUp/PgDn`,
  not `Pgup/Pgdn`). Keep identifiers such as `pi` and tool names (`edit`,
  `web_search`) literal, and longer text (descriptions, warnings, preview
  meta) in sentence case.
- **Spacing:** inside borders, one blank row at the top and bottom and one
  after the title; exactly one blank row before each subheader.
- **Fixed-height views:** put spare rows inside a section, not next to a
  required separator, or one-row spacing silently turns into several blank
  rows. Every rendered line still respects the supplied width.
