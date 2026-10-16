/**
 * In-process Pi runtime for tests: the pinned Pi packages run through
 * `createAgentSession()` against the loopback mock provider, with no
 * discovered resources, no user settings, and an in-memory session. No real
 * model is ever called.
 */
import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { TestContext } from "node:test";

import {
	type AgentSession,
	createAgentSession,
	DefaultResourceLoader,
	type ExtensionContext,
	type ExtensionFactory,
	ModelRuntime,
	SessionManager,
	SettingsManager,
} from "@earendil-works/pi-coding-agent";

import { type MockApi, type MockProvider, startMockProvider } from "./mock-provider.ts";
import { useSettings } from "./settings.ts";

/** Provider name under which the mock model is registered. */
export const MOCK_PROVIDER = "mock";

/** Id of the single mock model. */
export const MOCK_MODEL = "mock";

/** Options of one runtime. */
export interface RuntimeOptions {
	/** Extension factories in load order, such as the extension and test fixtures. */
	readonly extensions: readonly ExtensionFactory[];
	/** API the mock model speaks; defaults to OpenAI Completions. */
	readonly api?: MockApi;
	/** Active tools; defaults to none. */
	readonly tools?: readonly string[];
	/** Mode the extensions are bound in; defaults to `"rpc"`, where `ctx.hasUI` is true without a terminal. */
	readonly mode?: ExtensionContext["mode"];
}

/** A running Pi session with the provider it talks to. */
export interface Runtime {
	readonly session: AgentSession;
	readonly provider: MockProvider;
	/** Extension handler errors as `<event>: <message>`, in arrival order. */
	readonly errors: readonly string[];
}

type Model = NonNullable<ExtensionContext["model"]>;

/** Start a runtime that is disposed, with its provider and directory, when the test ends. */
export async function createRuntime(t: TestContext, options: RuntimeOptions): Promise<Runtime> {
	const api = options.api ?? "openai-completions";
	const provider = await startMockProvider();
	t.after(() => provider.close());
	// After hooks run in registration order: the session must stop before its directory is removed
	let stopSession: (() => void) | undefined;
	t.after(() => stopSession?.());
	const directory = await mkdtemp(join(tmpdir(), "{{package}}-test-"));
	t.after(() => rm(directory, { recursive: true, force: true }));

	const settingsManager = SettingsManager.inMemory({
		cacheWarming: "off", compaction: { enabled: false }, retry: { enabled: false },
	});
	useSettings(t, directory, () => settingsManager);
	const modelRuntime = await ModelRuntime.create({
		authPath: join(directory, "auth.json"), modelsPath: null, refreshOnCreate: false, allowModelNetwork: false,
	});
	const model = createMockModel(provider, api);
	const resourceLoader = new DefaultResourceLoader({
		cwd: directory, agentDir: directory, settingsManager,
		noExtensions: true, noSkills: true, noPromptTemplates: true, noThemes: true, noContextFiles: true,
		extensionFactories: [
			(pi) => pi.registerProvider(MOCK_PROVIDER, { api, baseUrl: model.baseUrl, apiKey: "mock-key", models: [model] }),
			...options.extensions,
		],
	});
	await resourceLoader.reload();

	const { session, extensionsResult } = await createAgentSession({
		cwd: directory, agentDir: directory, settingsManager, resourceLoader, modelRuntime, model,
		sessionManager: SessionManager.inMemory(directory), tools: [...(options.tools ?? [])], thinkingLevel: "off",
	});
	stopSession = () => session.dispose();
	assert.deepEqual(extensionsResult.errors, []);
	const errors: string[] = [];
	await session.bindExtensions({
		mode: options.mode ?? "rpc",
		onError: (error) => { errors.push(`${error.event}: ${error.error}`); },
	});
	return { session, provider, errors };
}

/** The text-only mock model for `api`, served by `provider`. */
function createMockModel(provider: MockProvider, api: MockApi): Model {
	return {
		provider: MOCK_PROVIDER, id: MOCK_MODEL, name: MOCK_MODEL, api, baseUrl: provider.baseUrls[api],
		reasoning: false, input: ["text"], contextWindow: 100_000, maxTokens: 128,
		cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
	};
}
