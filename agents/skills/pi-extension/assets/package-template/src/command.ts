/**
 * Command-line grammar for `/{{command}}`.
 *
 * Pure parsing and completion helpers with no `pi` access, so the whole command
 * surface is unit-testable without a running agent.
 */
import type { AutocompleteItem } from "@earendil-works/pi-tui";

/** Views the command can open. */
export type View = "{{arg-a}}" | "{{arg-b}}";

/** Parsed command line: either a view to open or a message to report. */
export type ParsedCommand = { type: "view"; view: View } | { type: "invalid"; message: string };

const VIEWS: View[] = ["{{arg-a}}", "{{arg-b}}"];
const USAGE = "Usage: /{{command}} [{{arg-a}}|{{arg-b}}]";

/** Parse command arguments; an empty argument selects the default view. */
export function parseCommand(args: string): ParsedCommand {
	const tokens = args.trim().toLowerCase().split(/\s+/).filter(Boolean);
	if (tokens.length === 0) return { type: "view", view: "{{arg-a}}" };
	if (tokens.length > 1) return { type: "invalid", message: USAGE };
	const view = VIEWS.find((candidate) => candidate === tokens[0]);
	return view === undefined ? { type: "invalid", message: USAGE } : { type: "view", view };
}

/** Completions for the argument prefix, or null when nothing matches. */
export function getArgumentCompletions(prefix: string): AutocompleteItem[] | null {
	const matches = VIEWS.filter((view) => view.startsWith(prefix.trim().toLowerCase()));
	return matches.length === 0 ? null : matches.map((view) => ({ value: view, label: view }));
}
