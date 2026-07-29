import assert from "node:assert/strict";
import { test } from "node:test";

import { getArgumentCompletions, parseCommand } from "../src/command.ts";

test("parseCommand defaults to the first view and rejects unknown grammar", () => {
	assert.deepEqual(parseCommand(""), { type: "view", view: "{{arg-a}}" });
	assert.deepEqual(parseCommand(" {{arg-b}} "), { type: "view", view: "{{arg-b}}" });
	assert.equal(parseCommand("unknown").type, "invalid");
	assert.equal(parseCommand("{{arg-a}} extra").type, "invalid");
});

test("getArgumentCompletions offers only known views", () => {
	assert.deepEqual(
		getArgumentCompletions("")?.map((item) => item.value),
		["{{arg-a}}", "{{arg-b}}"],
	);
	assert.equal(getArgumentCompletions("unknown"), null);
});
