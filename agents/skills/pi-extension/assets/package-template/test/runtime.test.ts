import assert from "node:assert/strict";
import { test, type TestContext } from "node:test";

import type { ExtensionFactory } from "@earendil-works/pi-coding-agent";

import extension from "../src/index.ts";
import { createRuntime } from "./harness/runtime.ts";

test("a normal turn sends the same provider request with and without the extension", async (t) => {
	const [baseline, withExtension] = await Promise.all([recordRequestBody(t, []), recordRequestBody(t, [extension])]);
	assert.equal(withExtension, baseline);
});

/**
 * Run one prompt with `extensions` loaded and return the body of its single provider request as JSON. Each
 * runtime has its own temporary cwd, so the cwd is replaced with a fixed placeholder.
 */
async function recordRequestBody(t: TestContext, extensions: ExtensionFactory[]): Promise<string> {
	const runtime = await createRuntime(t, { extensions });
	runtime.provider.enqueue({ text: "ok" });
	await runtime.session.prompt("Say one word: ok");

	assert.deepEqual(runtime.errors, []);
	assert.equal(runtime.provider.requests.length, 1);
	const body = JSON.stringify(runtime.provider.requests[0].body);
	return body.replaceAll(runtime.session.sessionManager.getCwd(), "<cwd>");
}
