import assert from "node:assert/strict";
import { suite, test } from "node:test";

import type { ExtensionFactory } from "@earendil-works/pi-coding-agent";

import extension from "../src/index.ts";
import marker from "./fixtures/marker.ts";
import { createRuntime } from "./harness/runtime.ts";

/** Both load orders of the extension and another extension that injects context. */
const LOAD_ORDERS: Record<string, ExtensionFactory[]> = {
	"extension first": [extension, marker],
	"marker first": [marker, extension],
};

suite("a normal turn with the extension loaded", { concurrency: true }, () => {
	for (const [order, extensions] of Object.entries(LOAD_ORDERS)) {
		test(`${order}: one prompt makes one provider request and keeps other injections`, async (t) => {
			const runtime = await createRuntime(t, { extensions });
			runtime.provider.enqueue({ type: "text", text: "ok" });
			await runtime.session.prompt("Say one word: ok");

			assert.deepEqual(runtime.errors, []);
			assert.equal(runtime.provider.requests.length, 1);
			const payload = JSON.stringify(runtime.provider.requests[0].body);
			assert.match(payload, /XYZZY_MARKER_INJECTION/);
			assert.match(payload, /XYZZY_MARKER_MESSAGE/);
			assert.match(payload, /Say one word: ok/);
		});
	}
});
