/**
 * Verification fixture that simulates another extension injecting a per-turn
 * system-prompt addition and a hidden startup message.
 *
 * Load it before and after the extension under test (`pi -e ./test/fixtures/marker.ts
 * -e .` and the reverse) to prove behavior is load-order independent.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.on("before_agent_start", async (event) => {
		return {
			systemPrompt: `${event.systemPrompt}\n\nXYZZY_MARKER_INJECTION: verification prompt addition.`,
		};
	});

	pi.on("session_start", async () => {
		pi.sendMessage(
			{
				customType: "{{package}}-marker",
				content: "XYZZY_MARKER_MESSAGE: hidden startup context message.",
				display: false,
			},
			{ deliverAs: "nextTurn", triggerTurn: false },
		);
	});
}
