import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function staticWorkingIndicator(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setWorkingIndicator({ frames: [ctx.ui.theme.fg("accent", "●")] });
  });
}
