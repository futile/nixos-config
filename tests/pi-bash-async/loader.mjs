// Pi provides these peer modules to extensions at runtime; tests get small stand-ins.
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";

const stubs = {
  "@earendil-works/pi-coding-agent": "./stubs/pi-coding-agent.mjs",
  "@earendil-works/pi-tui": "./stubs/pi-tui.mjs",
  "@earendil-works/pi-ai/compat": "./stubs/pi-ai-compat.mjs",
  typebox: "./stubs/typebox.mjs",
};

export async function resolve(specifier, context, next) {
  if (specifier in stubs) return { url: new URL(stubs[specifier], import.meta.url).href, shortCircuit: true };
  // The package imports its TypeScript siblings by their emitted `.js` names.
  if (specifier.startsWith(".") && specifier.endsWith(".js") && context.parentURL) {
    const ts = new URL(specifier.slice(0, -3) + ".ts", context.parentURL);
    if (!existsSync(fileURLToPath(new URL(specifier, context.parentURL))) && existsSync(fileURLToPath(ts)))
      return { url: ts.href, shortCircuit: true };
  }
  return next(specifier, context);
}
