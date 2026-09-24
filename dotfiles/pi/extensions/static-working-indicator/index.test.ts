import assert from "node:assert/strict";
import { test } from "node:test";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import staticWorkingIndicator from "./index.ts";

test("sets a single working frame on session start", () => {
  let start: ((event: unknown, ctx: ExtensionContext) => void) | undefined;
  const pi = {
    on: (_event: string, handler: typeof start) => { start = handler; },
  } as unknown as ExtensionAPI;
  staticWorkingIndicator(pi);

  const indicators: unknown[] = [];
  const ctx = {
    hasUI: true,
    ui: {
      theme: { fg: (_color: string, text: string) => `<${text}>` },
      setWorkingIndicator: (options: unknown) => indicators.push(options),
    },
  } as unknown as ExtensionContext;
  start?.({}, ctx);
  assert.deepEqual(indicators, [{ frames: ["<●>"] }]);
});
