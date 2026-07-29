/**
 * {{package}} — {{one-line description}}.
 *
 * The factory only registers; all work starts from lifecycle events so that
 * invocations which never open a session stay free of side effects.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { getArgumentCompletions, parseCommand } from "./command.ts";

/** Namespaced entry type so state written by this extension is identifiable. */
const STATE_CUSTOM_TYPE = "{{package}}:state";

export default function (pi: ExtensionAPI) {
	// Closure state only; everything needed after resume, reload, or fork is
	// rebuilt in session_start from persisted entries.
	let invocations = 0;

	pi.on("session_start", (_event, ctx) => {
		for (const entry of ctx.sessionManager.getEntries()) {
			if (entry.type === "custom" && entry.customType === STATE_CUSTOM_TYPE) {
				const data = entry.data as { invocations?: number };
				invocations = data.invocations ?? invocations;
			}
		}
	});

	pi.on("session_shutdown", () => {
		// Idempotent: may run twice, and may run without a matching session_start.
	});

	pi.registerCommand("{{command}}", {
		// RegisteredCommand has no argumentHint; mimic pi's `<hint> — <description>` style.
		description: "[{{arg-a}}|{{arg-b}}] — {{what the command does}}",
		getArgumentCompletions: getArgumentCompletions,
		handler: async (args, ctx) => {
			const command = parseCommand(args);
			if (command.type === "invalid") {
				if (ctx.hasUI) ctx.ui.notify(command.message, "error");
				return;
			}
			if (ctx.mode !== "tui") {
				if (ctx.hasUI) ctx.ui.notify("/{{command}} requires TUI mode.", "warning");
				return;
			}
			invocations += 1;
			pi.appendEntry(STATE_CUSTOM_TYPE, { invocations });
			// await showView(ctx, ...) — keep TUI components in src/ui/.
		},
	});
}
