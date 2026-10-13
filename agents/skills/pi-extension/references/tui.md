# Pi TUI Reference

Using `@earendil-works/pi-tui` and `ctx.ui` from extensions, verified against
Pi 1.1.0. Fullscreen is the default; `--tui-mode regular` restores terminal
scrollback. Inside a component factory, `tui.mode` distinguishes these modes
(`ctx.mode` is `"tui"` for both).

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
- [Mouse and fullscreen](#mouse-and-fullscreen)
- [Theming and invalidation](#theming-and-invalidation)
- [Transcript renderers (messages and entries)](#transcript-renderers-messages-and-entries)
- [Overlays](#overlays)
- [Custom editor](#custom-editor)
- [Autocomplete providers](#autocomplete-providers)

## ctx.ui quick reference

Guard with `ctx.hasUI` for dialogs, notify, status, and string-array widgets.
Use `ctx.mode === "tui"` for `custom()` and editor/header/footer/widget component
factories. RPC ignores widget factories; it supports only string-array widgets.

| Method | Purpose |
|---|---|
| `select(title, options, { timeout?, signal? })` | pick one; `undefined` on cancel/timeout |
| `confirm(title, message, { timeout?, signal? })` | boolean; `false` on cancel/timeout |
| `input(title, placeholder?, { timeout?, signal? })` / `editor(title, prefill?)` | text input / multi-line |
| `notify(text, "info"\|"warning"\|"error")` | non-blocking toast |
| `setStatus(key, text)` | footer status; `undefined` clears |
| `setWidget(key, lines\|factory, { placement? })` | persistent content above (default) or `"belowEditor"` |
| `setFooter(factory)` / `setHeader(factory)` | replace footer/header; pass explicit `undefined` to restore |
| `setWorkingMessage(msg?)` / `setWorkingVisible(bool)` / `setWorkingIndicator({ frames, intervalMs }?)` | streaming loader customization |
| `setHiddenThinkingLabel(label?)` | collapsed thinking label text |
| `setTitle(text)` | terminal title |
| `setEditorText(text)` / `getEditorText()` / `pasteToEditor(text)` | editor content |
| `setEditorComponent(factory)` / `getEditorComponent()` | set or get the custom editor factory; pass explicit `undefined` to restore |
| `custom(factory, { overlay?, overlayOptions?, onHandle? })` | temporary full custom component |
| `onTerminalInput(handler)` | TUI-only raw input interception; returns unsubscribe |
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

Timed auto-dismiss: `{ timeout: 5000 }` shows a countdown but returns the same
value as user cancel. To distinguish them, use your own `AbortController` and
timer instead of `timeout`, pass its `signal`, then check
`controller.signal.aborted`; clear the timer in `finally`.
Only `select`, `confirm`, and `input` accept these options; `editor` does not.

These dialogs and `ctx.ui.custom()` automatically emit
`ui_prompt_start`/`ui_prompt_end`; status integrations can observe the
coalesced waiting span described in [api.md](api.md#ui-prompt-lifecycle).

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
`ctx.ui.theme.fg(...)`. The default editor embeds working/retry/compaction
indicators in its border. Custom editors keep a standalone indicator unless
they opt in; inspect the installed editor APIs before changing that behavior.

## Component interface

```typescript
interface Component {
	render(width: number): string[];   // one string per line, each <= width
	handleInput?(data: string): void;  // when focused
	handleMouse?(event: TuiMouseEvent): TuiMouseEventResult | undefined;
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

Also from pi-tui: `SelectList`, `SettingsList`, `Input`, `Editor`,
`TruncatedText`, `VStack`, `HStack`, `ScrollView`, `MouseRegion`, `Loader`,
`CancellableLoader`. From pi-coding-agent: `DynamicBorder`, `BorderedLoader`,
`CustomEditor`, `getSettingsListTheme()`. Prefer these over rebuilding layout,
scrolling, selection, or input; check constructors in the installed types.

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
2. Invalidate affected cached output and call `tui.requestRender()` after state
   changes in `handleInput` or `handleMouse`.
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
`Home`/`End` move to the editor line start/end; fullscreen transcript top/bottom
use `Ctrl+Home`/`Ctrl+End` (`tui.altScreen.top` / `tui.altScreen.bottom`). Keep
custom editors from stealing those application-level navigation actions.

## Mouse and fullscreen

`handleMouse(event)` receives normalized zero-based local `x/y`, terminal
`screenX/screenY`, bounds, modifiers, button, and event type. Types include
`press`, `release`, `move`, `drag`, `click`, and `wheel`; wheel events have
`wheelDelta`, clicks may have `clickCount`. Return `{ handled?, capture?,
focus?, render? }` to control propagation, dragging, keyboard focus, and redraw.

Prefer `MouseRegion` around a child or `ScrollView` for a bounded viewport.
Unhandled wheels scroll the nearest scroll view; unhandled primary drags
remain available for transcript selection. OSC 8 links take precedence over
an enclosing click region. Regular mode leaves mouse input to the terminal,
so every action must remain reachable from the keyboard.

Test both display modes, resize/width limits, Unicode, theme changes, overlay
focus and close, scrolling, and any mouse paths. Capture the live tmux pane
before closing fullscreen mode, since terminal scrollback is not the live UI.

## Theming and invalidation

The default `system` theme derives colors from the terminal and may update
after startup or an appearance change. Never assume a fixed dark background.
`theme.appearance` is `"dark" | "light"`; `theme.colors` exposes concrete
colors for color math (terminal defaults use reported or fallback colors).

`theme.style(text, { fg?, bg?, bold?, ... })` combines semantic colors and
attributes. For a foreground token as a background, use its concrete color,
e.g. `{ bg: theme.colors.accent }`. Use pi-tui's `mixColors()` when necessary,
not hardcoded ANSI/hex values. Cache concrete-color calculations outside the
render path and rebuild them on invalidation. For theme files, read
`docs/themes.md` (`#rgb`, OKLCH, OKHSL, and optional `appearance` are supported).

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
  entries (persisted in all modes, rendered only in TUI, NOT in LLM context).
  Use for durable status cards that should survive resume.
- `pi.registerToolRenderer((toolName, next) => renderers)` — rendering-only
  resolution for any tool, including unregistered MCP tools in resumed sessions;
  see [tools.md](tools.md#rendering) for chaining, `durationMs`, and `outputPad`.
- `pi.registerMarkdownTransformer((markdown, context) => string)` — display-only
  user/assistant/thinking Markdown transformation. It does not redact stored
  history or model context. `context` includes `messageType`, `isStreaming`,
  and `availableWidth`; message renderer options also expose `outputPad`.

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
argument, never a captured theme. Respect the `outputPad` setting (0 or 1)
when owning transcript framing; Pi applies it to messages, tool output, `!`
output, and summary blocks. The default tool shell applies it for you;
`renderShell: "self"` must use `context.outputPad` itself.

## Overlays

`ctx.ui.custom(factory, { overlay: true, overlayOptions, onHandle })` renders
on top of existing content. `overlayOptions` can be an object or a callback.
Options: `width/maxHeight` (number or percentage), `minWidth` (number),
`anchor` (9 positions), `offsetX/offsetY`, `row/col`, `margin`,
`visible: (w, h) => boolean`, and `nonCapturing`.

The handle supports `focus()`, `unfocus()` or `unfocus({ target })`,
`setHidden(bool)`, `isHidden()`, `isFocused()`, and `getBounds()`. Focused
overlays retain input ownership; release focus explicitly when needed.

**Close with the factory's `done(value)` callback. Never call
`OverlayHandle.hide()` for a `ctx.ui.custom()` overlay:** it removes the
screen without completing the interaction. Use `setHidden()` only for
temporary visibility changes while the interaction is active.

Components are disposed on completion; never reuse closed instances. Re-call
the factory to re-show.

## Custom editor

Extend `CustomEditor` (from pi-coding-agent, not base `Editor`) to keep app
keybindings (escape to abort, ctrl+d, model switching). The editor factory's
`theme` is an `EditorTheme` (border/autocomplete callbacks), not the full
semantic `Theme` passed to `custom()`, widgets, headers, and footers:

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

To compose with another extension's editor, capture the factory returned by
`ctx.ui.getEditorComponent()` before setting yours. Invoke it with the new
factory's `(tui, editorTheme, keybindings)` arguments and wrap the resulting
component; it is not an existing editor instance. An absent factory means the
default editor. Use `ctx.ui.setEditorComponent(undefined)` to restore it.

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
