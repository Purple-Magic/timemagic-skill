# Errors, Access Rules & Rate Limits

## Status codes

| Status | Meaning | Body |
|---|---|---|
| 200 | success (read/update) | resource JSON or array |
| 201 | created | resource JSON |
| 204 | deleted | empty |
| 401 | missing/invalid token | `{"errors": "Unauthorized"}` |
| 402 | GET without active subscription | `{"info": "Subscription required for GET requests."}` |
| 404 | not found / not owned by this user | `{"errors": "Not found"}` |
| 422 | validation failure | `{"errors": {"<field>": ["<message>", ...]}}` (standard Rails `errors.as_json`) |
| 429 | rate limit exceeded | `{"info": "Rate limit exceeded. Try again later."}` |
| 500 | server error — e.g. hitting an unimplemented `event` value (see `tasks.md`) | opaque, not a clean API error |

Note the two different error envelopes: `errors` for auth/not-found/validation, `info` for subscription/rate-limit. Check which key is present rather than assuming one shape.

## Access rules

- GET requires an active subscription on the account; writes (POST/PUT/PATCH/DELETE) do not.
- Ownership is always scoped to the token's user — cross-user access returns `404`, not `403`, to avoid leaking existence.

## Rate limits

- 5 requests/minute per user, app-level (`Rails.cache` counter), no rate-limit headers.
- Pace bulk operations; a 429 means wait, not retry-immediately.

## General conventions

- All `:id` route params are UUIDs (field name `uuid` in responses, used directly as the path segment).
- Collections → bare JSON arrays. Singles → bare JSON objects. No envelope key like `{"data": ...}`.
- Write bodies wrap params in a singular resource key (`project`, `task`, `activity`, `goal`, `time_entry`, `estimation`, `report`).
- Timestamps are ISO-8601 strings.
