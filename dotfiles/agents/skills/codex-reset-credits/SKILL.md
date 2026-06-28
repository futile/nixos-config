---
name: codex-reset-credits
description: Use when the user asks when Codex usage-limit reset credits expire, asks to check banked Codex reset credits, or asks about Codex reset-credit expiry without redeeming them.
---

# Codex Reset Credits

Use the local checker to report banked Codex reset-credit expiry times without
redeeming credits.

## Steps

1. State that this uses an undocumented internal ChatGPT/Codex endpoint that may
   break without notice.
2. Run:

   ```sh
   check-codex-reset-credits
   ```

3. If the command is not found on `PATH`, check for
   `~/nixos/bin/check-codex-reset-credits` and run that path if present.
4. Report only the available-credit count and expiry times.

## Safety

- Do not invoke `/usage` redemption.
- Do not print bearer tokens, raw endpoint JSON, or raw `auth.json`.
- Do not use POST, PUT, PATCH, or DELETE for this check.
- If the script returns 401 or 403, ask the user to refresh Codex login.

See `docs/codex-reset-credits.md` for the endpoint notes and script options.
