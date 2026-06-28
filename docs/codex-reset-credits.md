# Codex Reset Credit Expiry

This repo includes a small read-only checker for banked Codex usage-limit reset
credits:

```sh
check-codex-reset-credits
```

It reports expiry times without redeeming reset credits.

## Context

Codex `/usage` shows usage and can redeem a reset, but does not currently show
reset-credit expiry timestamps. The unofficial
[`ashenafee/codex-reset-checker`](https://github.com/ashenafee/codex-reset-checker)
repo documents an internal, unsupported endpoint:

```text
GET https://chatgpt.com/backend-api/wham/rate-limit-reset-credits
```

Calling that endpoint with the local Codex ChatGPT access token returned
available reset credits and `expires_at` timestamps. The request is read-only:
it did not redeem credits or mutate account state.

## Usage

```sh
check-codex-reset-credits
```

Optional output and filtering:

```sh
check-codex-reset-credits --json
check-codex-reset-credits --timezone America/New_York
check-codex-reset-credits --include-inactive
```

If the command is not found on `PATH`, check whether it exists at
`~/nixos/bin/check-codex-reset-credits`.

The script prints only non-sensitive fields: check time, available count,
expiry timestamps, and time remaining.

## Auth And Headers

Read auth from:

```text
${CODEX_HOME:-~/.codex}/auth.json
```

Use:

- `tokens.access_token` as the bearer token.
- `tokens.id_token`, `tokens.access_token`, or `tokens.account_id` to derive
  `ChatGPT-Account-Id` when available.
- JWT account id lives at:

```text
https://api.openai.com/auth.chatgpt_account_id
```

Request headers used successfully:

```text
Authorization: Bearer <tokens.access_token>
originator: Codex Desktop
OAI-Product-Sku: CODEX
Accept: application/json
User-Agent: Mozilla/5.0 CodexDesktop/0.1.0
ChatGPT-Account-Id: <optional account id>
```

## Safety Notes

- This is not a public API and can break without notice.
- Keep the script read-only: no POST/PUT/PATCH/DELETE, no writing auth files.
- Never log `Authorization`, `access_token`, `id_token`, or raw `auth.json`.
- If the endpoint returns 401/403, ask the user to refresh Codex login instead
  of trying alternate credential sources.
