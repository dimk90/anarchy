import assert from "node:assert/strict";
import { test } from "node:test";

import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@earendil-works/pi-coding-agent";

import extension from "../src/index.ts";

/** Only the state entries consumed by this template's restoration handler. */
interface StateEntry {
	type: "custom";
	customType: string;
	data: { invocations: number };
}

/** Run the wiring against a minimal host; raw history must never be read. */
function createHarness() {
	let branch: StateEntry[] = [];
	const writes: unknown[] = [];
	const handlers = new Map<string, () => Promise<void>>();
	let command: ((args: string, ctx: ExtensionCommandContext) => Promise<void>) | undefined;
	const context = {
		mode: "tui",
		hasUI: true,
		sessionManager: {
			getBranch: () => branch,
			getEntries: () => { throw new Error("Do not restore abandoned branches"); },
		},
	} as unknown as ExtensionCommandContext;
	const api = {
		on(name: string, handler: (event: unknown, ctx: ExtensionContext) => void | Promise<void>) {
			handlers.set(name, async () => { await handler({}, context); });
			return () => { handlers.delete(name); };
		},
		registerCommand(_name: string, options: { handler: typeof command }) {
			command = options.handler;
		},
		appendEntry(_name: string, data: unknown) { writes.push(data); },
	} as unknown as ExtensionAPI;
	extension(api);
	return {
		writes,
		/** Select another branch snapshot without recreating the extension. */
		setBranch(invocations?: number) {
			branch = invocations === undefined ? [] : [{
				type: "custom", customType: "{{package}}:state", data: { invocations },
			}];
		},
		/** Invoke a registered lifecycle handler with this host's context. */
		async emit(name: string) {
			const handler = handlers.get(name);
			assert.ok(handler, `Missing handler: ${name}`);
			await handler();
		},
		/** Run the command without constructing terminal components. */
		async invoke() {
			assert.ok(command);
			await command("", context);
		},
	};
}

test("state follows the active branch on startup and tree navigation", async () => {
	const harness = createHarness();
	harness.setBranch(5);
	await harness.emit("session_start");
	await harness.invoke();
	harness.setBranch(2);
	await harness.emit("session_tree");
	await harness.invoke();
	harness.setBranch();
	await harness.emit("session_tree");
	await harness.invoke();
	assert.deepEqual(harness.writes, [{ invocations: 6 }, { invocations: 3 }, { invocations: 1 }]);
});
