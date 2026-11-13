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
| 409 | Trash restore refused because the item was already restored or another restore is running (see `trash.md`) | `{"errors": {"category": "...", "message": "..."}}` |
| 422 | validation failure | `{"errors": {"<field>": ["<message>", ...]}}` (standard Rails `errors.as_json`) |
| 426 | the skill's `X-TimeMagic-API-Version` is not supported by the API: the skill is out of date (checked before authentication) | `{"errors": "...", "code": "skill_update_required", "requested_api_version": "0", "supported_api_versions": ["1"], "current_api_version": "1", "update_url": "https://github.com/purple-magic/timemagic-skill"}` |
| 429 | rate limit exceeded | `{"info": "Rate limit exceeded. Try again later."}` |
| 500 | server error — e.g. hitting an unimplemented `event` value (see `tasks.md`) | opaque, not a clean API error |

Note the two different error envelopes: `errors` for auth/not-found/validation, `info` for subscription/rate-limit. Check which key is present rather than assuming one shape.

## Access rules

- GET requires an active subscription on the account; writes (POST/PUT/PATCH/DELETE) do not.
- Ownership is always scoped to the token's user — cross-user access returns `404`, not `403`, to avoid leaking existence.

## Rate limits

- 5 requests/minute per user, app-level (`Rails.cache` counter), no rate-limit headers.
- Pace bulk operations (~1 request per 12 seconds); a 429 means wait at least a minute, not retry-immediately.
- Plan within this budget: count the calls a job needs up front, prefer calls that return more data, never run TimeMagic calls in parallel (see "Respect the rate limit when planning work" in `SKILL.md`).

## General conventions

- All `:id` route params are UUIDs (field name `uuid` in responses, used directly as the path segment).
- Collections → bare JSON arrays. Singles → bare JSON objects. No envelope key like `{"data": ...}`.
- Write bodies wrap params in a singular resource key (`project`, `task`, `activity`, `goal`, `time_entry`, `estimation`, `report`).
- Timestamps are ISO-8601 strings.
