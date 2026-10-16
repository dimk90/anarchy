import assert from "node:assert/strict";
import { test } from "node:test";

import { VERSION } from "@earendil-works/pi-coding-agent";

import { isSupportedPiVersion, MIN_PI_VERSION } from "../src/pi-version.ts";

const [MAJOR, MINOR, PATCH] = MIN_PI_VERSION.split(".").map(Number);

test("isSupportedPiVersion accepts the minimum and newer releases", () => {
	const newer = [
		MIN_PI_VERSION,
		`v${MIN_PI_VERSION}`,
		`${MIN_PI_VERSION}-beta.1`,
		`${MAJOR}.${MINOR}.${PATCH + 1}`,
		`${MAJOR}.${MINOR + 1}.0`,
		`${MAJOR + 1}.0.0`,
		`${MAJOR + 10}.0.0`,
	];
	for (const version of newer) assert.equal(isSupportedPiVersion(version), true, version);
	// The pinned development dependency must pass its own check
	assert.equal(isSupportedPiVersion(VERSION), true);
});

test("isSupportedPiVersion refuses releases before the minimum", () => {
	const older = [
		PATCH > 0 ? `${MAJOR}.${MINOR}.${PATCH - 1}` : undefined,
		MINOR > 0 ? `${MAJOR}.${MINOR - 1}.99` : undefined,
		MAJOR > 0 ? `${MAJOR - 1}.99.99` : undefined,
	].filter((version) => version !== undefined);
	for (const version of older) assert.equal(isSupportedPiVersion(version), false, version);
});

test("isSupportedPiVersion does not refuse a version it cannot parse", () => {
	for (const version of ["", "dev", "1.0"]) assert.equal(isSupportedPiVersion(version), true, version);
});
