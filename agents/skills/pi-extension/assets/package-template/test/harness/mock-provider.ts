/**
 * Loopback-only mock provider for the test harness. It serves OpenAI
 * Completions streaming, records every request body, and answers with
 * scripted text replies. Extend it when the extension needs more: other APIs,
 * tool calls, delays, or HTTP errors.
 */
import { once } from "node:events";
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";

/** One scripted answer; the queue falls back to `DEFAULT_REPLY` when empty. */
export interface MockReply {
	readonly text: string;
}

/** One HTTP request as the provider received it. */
export interface RecordedRequest {
	readonly body: Record<string, unknown>;
}

/** Running mock provider. */
export interface MockProvider {
	/** Base URL of the OpenAI Completions API. */
	readonly baseUrl: string;
	/** Every request in arrival order. */
	readonly requests: readonly RecordedRequest[];
	/** Queue replies for the next requests, in order. */
	enqueue(...replies: MockReply[]): void;
	close(): Promise<void>;
}

const DEFAULT_REPLY: MockReply = { text: "ok" };
const COMPLETIONS_PATH = "/v1/chat/completions";

/** Start the mock on an ephemeral loopback port. */
export async function startMockProvider(): Promise<MockProvider> {
	const requests: RecordedRequest[] = [];
	const replies: MockReply[] = [];

	const server = createServer((request, response) => {
		void handleRequest(request, response);
	});

	/** Record the request and stream the next reply. */
	async function handleRequest(request: IncomingMessage, response: ServerResponse): Promise<void> {
		// A long synchronous test can block the shared event loop past the 5 s keep-alive timeout; the server
		// then closes an idle connection just as the client reuses it, so open a new one for every request
		response.setHeader("Connection", "close");
		if (request.url !== COMPLETIONS_PATH) {
			response.writeHead(404).end();
			return;
		}
		const body = JSON.parse(await readBody(request)) as Record<string, unknown>;
		requests.push({ body });
		const reply = replies.shift() ?? DEFAULT_REPLY;
		const model = typeof body.model === "string" ? body.model : "mock";
		response.writeHead(200, { "Content-Type": "text/event-stream", "Cache-Control": "no-cache" });
		response.end(streamEvents(reply, model, requests.length).join(""));
	}

	server.listen(0, "127.0.0.1");
	await once(server, "listening");
	const address = server.address();
	if (!address || typeof address === "string") throw new Error("Mock provider has no TCP address");

	return {
		baseUrl: `http://127.0.0.1:${address.port}/v1`,
		requests,
		enqueue: (...next) => { replies.push(...next); },
		close: () => new Promise<void>((resolve, reject) => {
			server.close((error) => error ? reject(error) : resolve());
			server.closeAllConnections();
		}),
	};
}

/** Read the whole request body as UTF-8 text. */
async function readBody(request: IncomingMessage): Promise<string> {
	const chunks: Buffer[] = [];
	for await (const chunk of request) chunks.push(chunk as Buffer);
	return Buffer.concat(chunks).toString("utf8");
}

/** OpenAI Completions SSE frames for a text reply. */
function streamEvents(reply: MockReply, model: string, sequence: number): string[] {
	const chunk = (delta: unknown, finishReason: string | null, usage?: unknown) => ({
		id: `chatcmpl-${sequence}`, object: "chat.completion.chunk", model,
		choices: [{ index: 0, delta, finish_reason: finishReason }],
		...(usage ? { usage } : {}),
	});
	const usage = { prompt_tokens: 10, completion_tokens: 1, total_tokens: 11 };
	const first = chunk({ role: "assistant", content: reply.text }, null);
	const last = chunk({}, "stop", usage);
	return [first, last].map((data) => `data: ${JSON.stringify(data)}\n\n`).concat("data: [DONE]\n\n");
}
