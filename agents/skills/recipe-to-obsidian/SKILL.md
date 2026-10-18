---
name: recipe-to-obsidian
description: Translate recipes from any source language into Russian and save them as a Markdown note in the user's personal Obsidian template. Use whenever the user shares a recipe (image file of a recipe card, screenshot, pasted text, text/PDF file, or link) and wants it translated, converted, adapted, or saved as an Obsidian note — even without saying "Obsidian", and even if they just say "переведи" or "сохрани". Handles Finnish quirks (garlic timing ambiguity, ruokakerma, rkl/tl/dl units) automatically.
compatibility: Pi coding agent. Uses the read, write and bash tools. Image sources need a vision-capable model.
---

# Recipe → Obsidian (Russian)

Translate recipes into Russian and emit them in the user's Obsidian markdown template. Output is always a `.md` file written to disk that the user can drop straight into their vault — never a chat-only summary.

## When this skill fires

The user shares a recipe in any form (image path, screenshot, pasted text, file path, link) and wants it:
- translated to Russian, or
- formatted as an Obsidian note, or
- saved as a file they can keep.

If the request is ambiguous (e.g., they just say "переведи" with a recipe image attached), default to producing the Obsidian file — that's the user's standing preference.

Skip this skill only if the user explicitly asks for something else ("just read me what it says", "what's a Russian word for this Finnish ingredient").

## Workflow

1. **Read the source.**
   - **Image / screenshot** (`.jpg`, `.png`, `.webp`, …): open it with the `read` tool — it returns the image to you for visual reading. If the model can't see images, say so and ask the user to paste the text.
   - **Text / Markdown / HTML file**: `read` it.
   - **PDF**: extract text via `bash` (e.g. `pdftotext -layout "<file>" -`); if that's unavailable or the PDF is scanned, ask the user for an image or the text.
   - **Link**: pi has no built-in web tool. Use a web-fetch skill/tool if one is available; otherwise fetch with `bash` (e.g. `curl -sL "<url>"`) and pull the recipe out of the HTML (JSON-LD `"@type": "Recipe"` blocks are the most reliable). If the fetch fails, ask the user to paste the recipe.
   - **Pasted text**: use it directly.
   - If the source is unclear (handwriting, low-res, partial), say so and ask before guessing.
2. **Translate everything to Russian** — title, ingredients, steps, notes, footnotes.
3. **Apply the unit conventions** (see "Units" below).
4. **Apply language-specific quirks** — especially the Finnish ones (see "Finnish quirks" below).
5. **Rewrite steps to the user's granularity preference** (see "Step granularity" below).
6. **Write a single `.md` file** with the `write` tool using the exact template (see "Where to save" below), then reply with one short line giving the saved path. Don't paste the whole note back into the chat — it's already in the file.

## Where to save

- If the user names a folder or vault path, save there.
- Otherwise save into the current working directory.
- Never overwrite an existing note silently: if `<filename>.md` already exists, ask, or save as `<filename> (2).md`.

## Output template

Reproduce this exactly. Angle-bracket placeholders get replaced; everything else is literal.

```markdown
---

![[Cook - <короткое-название>.jpeg]]

> [!info] 
> <N> порций 🥘

## Ингредиенты
---
 * [x] **<Главный ингредиент>** - <кол-во с ед. изм.>.
 * [x] **<...>** - <...>.
 * Растительное масло.
 * Соль.
 * Черный молотый перец.

> [!multi-column|center-fixed]
>
>> [!note] 
>> ![[Cook - ingredient1.jpeg]]
>
>> [!note] 
>> ![[Cook - ingredient2.jpeg]]
>

## Приготовление
---

> [!tip|float-right-small] <Заголовок>
> <br>
> - <Важный совет>.

 * <Шаг 1>.
 * <Шаг 2, с таймером> `<N> минут ⌛`.
 ...

[^1]: <Сноска, если нужна>.
```

### Conventions inside the template

- **`* [x]` + bold name** for measured/main ingredients with explicit amounts (the "shopping list" items).
- **Plain `*` bullets without checkbox or bold** at the bottom for basic pantry items (соль, перец, растительное масло) — even when the source recipe specifies amounts. The cook adjusts to taste; precise amounts can be mentioned inline in the matching step instead.
- **Multi-column ingredient-photo placeholder** between the ingredients list and the `## Приготовление` header. Always include this stub — the user fills it with real photos later. Use `[!note]` callouts (not `[!tip]`) and placeholder filenames `Cook - ingredient1.jpeg`, `Cook - ingredient2.jpeg`. Default to 2 placeholders; the user adds more if they need them.
- **Image placeholder** `![[Cook - <name>.jpeg]]` near the top. Use a short descriptive name; the user replaces it with a real photo later.
- **Info callout** with portion count + 🥘 emoji.
- **Tip callouts** `[!tip|float-right-small]` only when there's something genuinely useful to highlight: a non-obvious technique, an oven-preheat reminder, an explicit serving suggestion from the source, or a clarification about an ambiguous step. Don't add a tip for the sake of having one.
- **Timer annotations** like `` `5 минут ⌛` `` — backticks + the ⌛ emoji, used inline in steps that have concrete durations.
- **Footnotes** `[^N]` at the bottom for source-recipe quirks worth preserving, glossary clarifications (e.g., what "ruokakerma" is), or compound items like a herb blend.
- **Indentation**: ingredient and step bullets are prefixed with a single leading space (` *`), matching the user's existing notes. Don't change this.
- **Skip trivial closing steps.** Don't include "Сразу же подавайте...", "Подавайте сразу", "Tarjoa heti" or similar serve-immediately closers — they're noise. The recipe ends when the food is ready; the cook doesn't need a reminder to bring it to the table. If the source has a meaningful serving suggestion (garnish, side dish, plating), put that in a tip callout instead.

### Filename

Short Russian title, sentence case, spaces preserved, `.md` extension. Examples:
- `Паста с лососем и спаржей.md`
- `Кальцоне с курицей.md`

No emojis in the filename by default — the user adds those themselves if they love the recipe.

## Units — always in Russian

Translate every unit to its Russian abbreviation. Fold the abbreviation into the amount string in the ingredient line (e.g., `1 ст. л.`, `200 мл`, `0.5 ч. л.`).

| Source | Russian |
|---|---|
| tbsp, T, столовая ложка, rkl, msk | ст. л. |
| tsp, t, чайная ложка, tl, tsk | ч. л. |
| cup | стакан |
| oz | унция |
| fl oz | жидкая унция |
| lb, pound | фунт |
| pinch | щепотка |
| g, gram, gr | г |
| kg | кг |
| ml | мл |
| l, liter, litre | л |
| dl (decilitre, десилитр) | мл — **convert** (1 дл = 100 мл) |

Convert dl to ml in the output (e.g., "1-2 дл воды" → "100-200 мл воды" or "≈150 мл воды"). Most Russian-speaking cooks read ml more readily than dl.

For temperatures, convert °F → °C. For imperial weights/volumes, convert if the result would be awkward in Russian context (e.g., `0.5 lb` → `≈225 г`). Keep imperial as-is only when it's culturally Anglo (oz of spirits, etc.).

## Step granularity

The user prefers fine-grained steps with a clear principle: **one ingredient = one prep step**, but multiple sub-actions on the same ingredient can combine.

**Yes, do this:**
- "Очистите и мелко нарежьте лук."
- "Очистите и мелко нарежьте чеснок." (separate step)
- "Удалите со спаржи деревянистую часть, слегка очистите и нарежьте наискосок на 3–4 части." (multiple actions, same ingredient → fine)
- "Помойте и нарежьте помидоры ломтиками."

**Don't do this:**
- "Подготовьте овощи: нарежьте лук, чеснок, спаржу..." (mixing ingredients into one step)
- "Очистите овощи и мелко нарежьте всё." (loses specificity)

**Cooking steps** break by phase, not by every gesture:
- "Добавьте лук и спаржу, обжаривайте `1-2 минуты ⌛`." ✓
- "Добавьте чеснок и обжарьте ещё `~1 минуту ⌛`." ✓ (separate because it's a distinct phase)
- "Приправьте солью и черным перцем." ✓ (separate from sauté)

**Splitting independent actions on the same ingredient** is fine:
- "Натрите в пасту цедру вымытого лимона."
- "Выжмите туда же сок лимона." (two distinct gestures, two steps)

When in doubt, lean granular — easier to follow while cooking.

## Translation quality

- Use natural Russian cooking vocabulary, not literal translations. "Brown the onion" → "обжарьте лук до золотистого цвета".
- Use the polite imperative ("вы"-form): "Очистите", "Нарежьте", "Добавьте".
- Preserve the source's structure (sections, intro notes, tips) but make them feel native in Russian.
- If something in the source is genuinely ambiguous or seems wrong, **add a footnote** rather than silently guessing.

## Finnish quirks 🇫🇮

Finnish recipe cards (Ruokaboksi, K-Ruoka, HOK-Elanto, etc.) have known patterns to handle.

### The garlic problem

In many Finnish recipes, the cooking steps say "Lisää sipulit pannulle" (lit. "add the onions to the pan", plural) when the ingredient list shows only `1 sipuli` (one onion) plus separate `valkosipulinkynnet` (garlic cloves). The garlic is chopped in the prep step but never explicitly added later.

**Always check this**: if garlic is in the ingredients but never explicitly added in the cooking steps, **insert a step** that adds the garlic **after the onion has sautéed for 1-2 minutes**, with a brief explanation that this is to avoid burning. Then add a tip-callout note (or footnote) explaining that the source was ambiguous and this is your interpretation.

Pattern:
```markdown
> [!tip|float-right-small] Совет
> <br>
> - Момент добавления чеснока в оригинале не указан явно — добавляйте после лука, чтобы не сгорел.

 * Добавьте лук и [другие овощи], обжаривайте `1-2 минуты ⌛`.
 * Добавьте чеснок и обжарьте ещё `~1 минуту ⌛`, чтобы он не сгорел.
 * Приправьте солью и черным перцем.
```

### Finnish term mapping

| Finnish | Russian |
|---|---|
| rkl (ruokalusikka) | ст. л. |
| tl (teelusikka) | ч. л. |
| dl (desilitra) | мл (1 дл = 100 мл) — convert |
| prk (purkki) | баночка / упаковка |
| pkt (pakkaus) | пакет / упаковка |
| ruukku | горшочек (со свежей зеленью) |
| nippu | пучок |
| kylmäsavu(lohi) | (лосось) холодного копчения |
| ruokakerma | кулинарные сливки 10-15% жирности — **add footnote** |
| kerma / kuohukerma | сливки / взбитые сливки |
| parsa | спаржа |
| sesongin | сезонный |
| sipuli | (репчатый) лук |
| valkosipuli | чеснок |
| valkosipulinkynsi | зубчик чеснока |
| tilli | укроп |
| persilja | петрушка |
| sitruuna | лимон |
| voi | сливочное масло |
| öljy | растительное масло |
| suola | соль |
| mustapippuri | чёрный перец |

### The ruokakerma footnote

If the recipe uses **ruokakerma**, always include this footnote (or a close variant):
> Финские ruokakerma — кулинарные сливки 10-15% жирности. Подойдут любые сливки для готовки.

This is helpful because Russian-speaking users outside Finland often don't have a direct equivalent on the shelf.

## Other source languages

For English, Italian, etc., no special quirks beyond standard translation. Apply unit conversions and granularity rules normally. If a source-specific term needs explanation (e.g., "buttermilk" → пахта), add a brief footnote.

If you spot a real ambiguity in any source (missing timing, mystery ingredient, step that doesn't reference an ingredient), add a footnote rather than guessing silently.

## Example

A complete worked example (Finnish pasta recipe → Russian Obsidian note) is in `references/example-pasta-salmon.md`. Read it whenever you need to anchor on the exact template, tip-callout style, footnote style, or step granularity. It demonstrates the garlic-insertion pattern and the ruokakerma footnote.
