# Pi TUI Reference

Using `@earendil-works/pi-tui` and `ctx.ui` from extensions.

## Contents

- [ctx.ui quick reference](#ctxui-quick-reference)
- [Dialogs](#dialogs)
- [Status, widgets, footer, working indicator](#status-widgets-footer-working-indicator)
- [Component interface](#component-interface)
- [Built-in components](#built-in-components)
- [Custom components via ctx.ui.custom()](#custom-components-via-ctxuicustom)
- [Ready-made patterns](#ready-made-patterns)
- [Pi-native selector style](#pi-native-selector-style)
- [Keyboard input](#keyboard-input)
- [Theming and invalidation](#theming-and-invalidation)
- [Transcript renderers (messages and entries)](#transcript-renderers-messages-and-entries)
- [Overlays](#overlays)
- [Custom editor](#custom-editor)
- [Autocomplete providers](#autocomplete-providers)

## ctx.ui quick reference

Guard with `ctx.hasUI` (dialogs, notify, status, widgets) or
`ctx.mode === "tui"` (`custom()`, editor/footer component factories).

| Method | Purpose |
|---|---|
| `select(title, options, { timeout?, signal? })` | pick one; `undefined` on cancel/timeout |
| `confirm(title, message, { timeout?, signal? })` | boolean; `false` on cancel/timeout |
| `input(title, placeholder?)` / `editor(title, prefill?)` | text input / multi-line |
| `notify(text, "info"\|"warning"\|"error")` | non-blocking toast |
| `setStatus(key, text?)` | footer status; `undefined` clears |
| `setWidget(key, lines\|factory, { placement? })` | persistent content above (default) or `"belowEditor"` |
| `setFooter(factory?)` / `setHeader(factory?)` | replace footer/header; `undefined` restores |
| `setWorkingMessage(msg?)` / `setWorkingVisible(bool)` / `setWorkingIndicator({ frames, intervalMs }?)` | streaming loader customization |
| `setHiddenThinkingLabel(label?)` | collapsed thinking label text |
| `setTitle(text)` | terminal title |
| `setEditorText(text)` / `getEditorText()` / `pasteToEditor(text)` | editor content |
| `setEditorComponent(factory?)` / `getEditorComponent()` | replace input editor |
| `custom(factory, { overlay?, overlayOptions?, onHandle? })` | temporary full custom component |
| `addAutocompleteProvider(factory)` | stack completion logic |
| `setToolsExpanded(bool)` / `getToolsExpanded()` | tool output expansion |
| `theme` / `setTheme(nameOrTheme)` / `getTheme(name)` / `getAllThemes()` | theming |

## Dialogs

```typescript
const choice = await ctx.ui.select("Pick one:", ["A", "B", "C"]);
const ok = await ctx.ui.confirm("Delete?", "This cannot be undone");
const name = await ctx.ui.input("Name:", "placeholder");
const text = await ctx.ui.editor("Edit:", "prefilled");
```

Timed auto-dismiss: `{ timeout: 5000 }` shows a countdown. To distinguish
timeout from user cancel, pass your own `AbortSignal` and check
`controller.signal.aborted` after.

## Status, widgets, footer, working indicator

```typescript
ctx.ui.setStatus("my-ext", ctx.ui.theme.fg("accent", "● active"));
ctx.ui.setStatus("my-ext", undefined);  // clear

ctx.ui.setWidget("my-widget", ["line 1", "line 2"]);          // above editor
ctx.ui.setWidget("my-widget", lines, { placement: "belowEditor" });
ctx.ui.setWidget("my-widget", (tui, theme) => ({ render: () => lines, invalidate() {} }));
ctx.ui.setWidget("my-widget", undefined);

ctx.ui.setFooter((tui, theme, footerData) => ({
	render: (width) => [`${footerData.getGitBranch() ?? "no git"}`],
	invalidate() {},
	dispose: footerData.onBranchChange(() => tui.requestRender()),
}));

ctx.ui.setWorkingIndicator({ frames: [ctx.ui.theme.fg("accent", "●")] });  // static
ctx.ui.setWorkingIndicator({ frames: [] });  // hide
ctx.ui.setWorkingIndicator();                // restore default spinner
```

Working-indicator frames render verbatim — color them yourself with
`ctx.ui.theme.fg(...)`.

## Component interface

```typescript
interface Component {
	render(width: number): string[];   // one string per line, each <= width
	handleInput?(data: string): void;  // when focused
	wantsKeyRelease?: boolean;         // receive key release events (Kitty protocol)
	invalidate(): void;                // clear caches (called on theme change)
}
```

Rules:

- **Never exceed `width`.** Use `truncateToWidth(str, width, ellipsis?)`;
  measure with `visibleWidth(str)` (ANSI-aware); wrap with
  `wrapTextWithAnsi(str, width)`.
- Styles do not carry across lines (TUI resets SGR per line) — reapply per line
  or use `wrapTextWithAnsi`.
- Cache rendered lines keyed on width; clear in `invalidate()`:

```typescript
render(width: number): string[] {
	if (this.cachedLines && this.cachedWidth === width) return this.cachedLines;
	// ...compute...
	this.cachedWidth = width; this.cachedLines = lines;
	return lines;
}
invalidate(): void { this.cachedWidth = undefined; this.cachedLines = undefined; }
```

Components with a text cursor should implement `Focusable` (a `focused`
field + `CURSOR_MARKER` in output) for IME support; containers embedding an
`Input`/`Editor` must propagate `focused` to the child.

## Built-in components

```typescript
import { Box, Container, Image, Markdown, Spacer, Text } from "@earendil-works/pi-tui";

new Text(content, paddingX = 1, paddingY = 1, bgFn?)   // .setText()
new Box(paddingX, paddingY, bgFn)                      // .addChild(), .setBgFn()
new Container()                                        // vertical group; .addChild/.removeChild/.clear
new Spacer(2)                                          // empty lines
new Markdown(md, paddingX, paddingY, mdTheme)          // use getMarkdownTheme() from pi-coding-agent
new Image(base64, "image/png", theme, { maxWidthCells, maxHeightCells })
```

Higher-level (also from pi-tui): `SelectList`, `SettingsList`, `Input`,
`Editor`; from pi-coding-agent: `DynamicBorder`, `BorderedLoader`,
`CustomEditor`, `getSettingsListTheme()`. **These cover 90% of cases — don't
rebuild them.**

## Custom components via ctx.ui.custom()

`ctx.ui.custom()` accepts a factory, waits until `done(value)` is called, and
returns that value. The factory receives `tui`, `theme`, and `keybindings`:

```typescript
import { Key, matchesKey, Text } from "@earendil-works/pi-tui";

const result = await ctx.ui.custom<boolean>((tui, theme, _keybindings, done) => {
	const text = new Text(theme.fg("accent", "Enter Confirm · Esc Cancel"), 1, 1);
	return {
		render: (width) => text.render(width),
		invalidate: () => text.invalidate(),
		handleInput: (data) => {
			if (matchesKey(data, Key.enter)) done(true);
			else if (matchesKey(data, Key.escape)) done(false);
			tui.requestRender();
		},
	};
});
```

Rules:

1. Use `theme` from the callback — never import or capture a theme elsewhere.
2. Call `tui.requestRender()` after state changes in `handleInput`.
3. Return an object with `render`, `invalidate`, and (if interactive)
   `handleInput` — wrap a `Container` when composing:
   `{ render: (w) => container.render(w), invalidate: () => container.invalidate(), handleInput: (d) => { list.handleInput(d); tui.requestRender(); } }`
4. Use injected `keybindings` (KeybindingsManager), not global getters.

## Ready-made patterns

**Selection dialog** (SelectList + DynamicBorder):

```typescript
import { DynamicBorder } from "@earendil-works/pi-coding-agent";
import { Container, type SelectItem, SelectList, Text } from "@earendil-works/pi-tui";

const result = await ctx.ui.custom<string | null>((tui, theme, _kb, done) => {
	const container = new Container();
	container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
	container.addChild(new Text(theme.fg("accent", theme.bold("Pick")), 1, 0));
	const list = new SelectList(items, Math.min(items.length, 10), {
		selectedPrefix: (t) => theme.fg("accent", t),
		selectedText: (t) => theme.fg("accent", t),
		description: (t) => theme.fg("muted", t),
		scrollInfo: (t) => theme.fg("dim", t),
		noMatch: (t) => theme.fg("warning", t),
	});
	list.onSelect = (item) => done(item.value);
	list.onCancel = () => done(null);
	container.addChild(list);
	container.addChild(new DynamicBorder((s: string) => theme.fg("accent", s)));
	return {
		render: (w) => container.render(w),
		invalidate: () => container.invalidate(),
		handleInput: (d) => { list.handleInput(d); tui.requestRender(); },
	};
});
```

**Async with cancel** (BorderedLoader): construct
`new BorderedLoader(tui, theme, "Fetching...")`, set `loader.onAbort = () =>
done(null)`, run work with `loader.signal`, `done(data)` when finished.

**Settings toggles**: `new SettingsList(items, height, getSettingsListTheme(),
onChange, onClose, { enableSearch: true })`.

## Pi-native selector style

Use `/settings` and `/model` as the visual reference for custom selectors. Keep
native components when they can express the UI; apply this checklist when a
hierarchical or specialized view requires custom rendering:

- **Theme colors:** draw every colored glyph through the current theme's
  semantic keys with `theme.fg(...)` (and theme-based colorizers for borders,
  e.g. `new DynamicBorder((t) => theme.fg("accent", t))`). Never hardcode hex,
  ANSI escape codes, or named terminal colors so views track the active theme.
- **Selection:** prefix the selected row with `theme.fg("accent", "→ ")` and
  color both its label and value with `accent`. Do not apply `selectedBg` or
  another full-row background.
- **Alignment:** reserve the cursor column for every row, then add hierarchy
  indentation after it. Parent and descendant cursors must align vertically.
- **Sub-headers:** render section sub-headers (e.g. `INITIAL`, `RUNTIME`) bold
  with `mdHeading` so they read as headings.
- **Hierarchy:** render main/group rows with `text`, first-level sub-items and
  unselected values with `muted`, and deeper sub-items with `dim`.
- **Metadata:** use `dim` for an overflow-only `(current/total)` indicator.
  Omit the line when every item is visible.
- **Hints:** compose each hint as dim key + muted description. Prefer
  `keyHint(binding, description)` or `rawKeyHint("↑↓", "Navigate")` instead
  of coloring or formatting keys manually. Join multiple hints with ` · `.
- **Description:** place a short `muted` explanation near the bottom, directly
  above hints, with one blank row before and after it.
- **Indentation:** keep headers, sub-headers, and the `→` cursor flush at
  column 0. Indent the muted description, the `(current/total)` counter, the
  hint row, and preview body content two spaces (reduce the wrap width to keep
  wrapped lines within the border).
- **Casing:** use Title Case for titles, section names, and hint labels
  (`Context Injections`, `Esc Close`), and conventional keyboard casing for
  key names (`PgUp/PgDn`, not `Pgup/Pgdn`). Keep recognizable identifiers such
  as `pi` and tool names (`edit`, `web_search`) in their literal casing, and
  keep longer descriptions (dialog descriptions, warnings, preview meta) in
  sentence case.
- **Spacing:** inside borders, keep one blank row at the top and bottom and one
  after the dialog title. Keep exactly one blank row between the title and the
  first subheader, and one before later subheaders.

When filling a fixed-height/fullscreen view, put spare rows inside a section
rather than next to a required separator; otherwise one-row spacing silently
turns into several blank rows. Every rendered line must still respect the
supplied width.

## Keyboard input

```typescript
import { Key, matchesKey } from "@earendil-works/pi-tui";

handleInput(data: string): void {
	if (matchesKey(data, Key.up)) { /* ... */ }
	else if (matchesKey(data, Key.enter)) { /* ... */ }
	else if (matchesKey(data, Key.escape)) { /* ... */ }
	else if (matchesKey(data, Key.ctrl("c"))) { /* ... */ }
}
```

String forms work too: `"enter"`, `"ctrl+c"`, `"shift+tab"`, `"ctrl+shift+p"`.
For displayed hints use `keyHint(id, desc)`/`keyText(id)` with namespaced ids
(`app.*` for coding-agent, `tui.*` for shared TUI bindings) — never hardcode.

## Theming and invalidation

`theme.fg(color, text)` colors: `text accent muted dim` / `success error
warning` / `border borderAccent borderMuted` / `toolTitle toolOutput` /
`toolDiffAdded toolDiffRemoved toolDiffContext` / `userMessageText
customMessageText customMessageLabel` / `md*` / `syntax*` / thinking levels
through `thinkingMax`.
`theme.bg(color, text)`: `selectedBg userMessageBg customMessageBg
toolPendingBg toolSuccessBg toolErrorBg`. Styles: `theme.bold/italic/strikethrough`.

Syntax highlighting: `highlightCode(code, lang, theme)` and
`getLanguageFromPath(path)` from `@earendil-works/pi-coding-agent`.

**Theme-change invalidation:** if you pre-bake theme colors into stored
strings/child components, override `invalidate()` to rebuild them:

```typescript
override invalidate(): void {
	super.invalidate();   // clear child caches
	this.rebuild();       // re-apply current theme colors
}
```

Not needed when you pass color callbacks (`(t) => theme.fg("accent", t)`) or
compute themed output fresh in every `render()`.

## Transcript renderers (messages and entries)

Control how extension-created content renders in the chat transcript:

- `pi.registerMessageRenderer(customType, renderer)` — for `pi.sendMessage()`
  custom messages (participate in LLM context).
- `pi.registerEntryRenderer(customType, renderer)` — for `pi.appendEntry()`
  custom entries (TUI-only, NOT in LLM context). Use for durable status
  cards/logs that should survive resume but never reach the LLM.

```typescript
import { Box, Text } from "@earendil-works/pi-tui";

pi.registerEntryRenderer("status-card", (entry, { expanded }, theme) => {
	const data = entry.data as { title: string; count: number };
	const box = new Box(1, 1, (t) => theme.bg("customMessageBg", t));
	box.addChild(new Text(`${theme.bold(data.title)}: ${data.count}`));
	if (expanded) box.addChild(new Text(theme.fg("dim", JSON.stringify(data, null, 2))));
	return box;
});

pi.appendEntry("status-card", { title: "Indexed files", count: 17 });
```

Renderers return a TUI `Component` (or `undefined` to hide). Use the `theme`
argument, never a captured theme.

## Overlays

`ctx.ui.custom(factory, { overlay: true, overlayOptions, onHandle })` renders
on top of existing content. `overlayOptions`: `width/minWidth/maxHeight`
(number or `"50%"`), `anchor` (9 positions), `offsetX/offsetY`, `row/col`,
`margin`, `visible: (w, h) => boolean`. `onHandle(handle)`: `focus()`,
`unfocus({ target? })`, `setHidden(bool)`, `hide()`.

Overlay components are disposed on close — never reuse instances; re-call the
factory to re-show.

## Custom editor

Extend `CustomEditor` (from pi-coding-agent, not base `Editor`) to keep app
keybindings (escape to abort, ctrl+d, model switching):

```typescript
class VimEditor extends CustomEditor {
	private mode: "normal" | "insert" = "insert";
	handleInput(data: string): void {
		if (this.mode === "insert") { /* mode switching */ super.handleInput(data); return; }
		switch (data) {
			case "i": this.mode = "insert"; return;
			case "h": super.handleInput("\x1b[D"); return;  // arrow passthrough
		}
		super.handleInput(data);  // unhandled keys go to app
	}
}

ctx.ui.setEditorComponent((tui, theme, keybindings) => new VimEditor(tui, theme, keybindings));
```

To compose with another extension's editor, capture
`ctx.ui.getEditorComponent()` before setting yours and wrap it. Pass
`undefined` to restore the default.

## Autocomplete providers

Stack on top of the built-in slash/path provider; delegate when your syntax
doesn't match:

```typescript
ctx.ui.addAutocompleteProvider((current) => ({
	triggerCharacters: ["#"],
	async getSuggestions(lines, line, col, options) {
		const match = (lines[line] ?? "").slice(0, col).match(/(?:^|[ \t])#([^\s#]*)$/);
		if (!match) return current.getSuggestions(lines, line, col, options);
		return { prefix: `#${match[1] ?? ""}`, items: [{ value: "#123", label: "#123", description: "..." }] };
	},
	applyCompletion(lines, line, col, item, prefix) {
		return current.applyCompletion(lines, line, col, item, prefix);
	},
	shouldTriggerFileCompletion(lines, line, col) {
		return current.shouldTriggerFileCompletion?.(lines, line, col) ?? true;
	},
}));
```
