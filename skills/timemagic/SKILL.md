---
name: timemagic
description: Interact with the TimeMagic API — a personal time-tracking and productivity app with projects, tasks, activities, goals, time entries, estimations, and reports. Use when the user asks to view/create/update TimeMagic projects, tasks, activities, goals, or time entries, to start/stop time tracking, to check what they tracked, or to build/integrate code against the TimeMagic API (https://time-app.purple-magic.com). Not for generic to-do lists or unrelated time-tracking tools.
license: MIT
---

# TimeMagic

TimeMagic is a personal time-tracking and productivity app. Its external API lets you read and manage a user's **projects**, **tasks**, **activities**, **goals**, **time entries**, **estimations**, and **reports**, and drive time-tracking workflows (start/stop tracking on tasks and activities).

Authoritative, always-current docs: `https://time-app.purple-magic.com/docs/api`. This skill's `references/` are a fast, offline-capable summary of that documentation cross-checked against the app's source — if something here seems off or the user mentions new fields/endpoints, treat the live docs as the source of truth.

## Setup

All requests need:

```
Authorization: Bearer <TIMEMAGIC_API_TOKEN>
Accept: application/json
Content-Type: application/json   # for requests with a body
```

Get the token from the `TIMEMAGIC_API_TOKEN` environment variable. If it's not set, tell the user to generate one at `https://time-app.purple-magic.com/docs/api` (logged in → API Token section → "Regenerate token") and set it as `TIMEMAGIC_API_TOKEN`. Never ask the user to paste the token into chat, never print it, and never write it into source files you generate — reference the env var instead.

Base URL: `https://<host>/api` (host is environment-specific; default to `https://time-app.purple-magic.com` unless the user gives another host).

## Core facts an agent must get right

- Resources are identified by **`uuid`**, not `id`. Every `:id` route segment is actually a UUID.
- Collection responses are plain **JSON arrays**, not `{"projects": [...]}`-style wrappers. Single-resource responses are plain JSON objects.
- Write bodies are wrapped in a singular root key matching the resource, e.g. `{"project": {...}}`, `{"task": {...}}`.
- **GET requests require an active TimeMagic subscription** on the token's account; writes (POST/PUT/PATCH/DELETE) do not. A `402` with `{"info": "..."}` means the account lacks a subscription — tell the user, don't retry.
- Rate limit: **5 requests/minute per user**, enforced server-side with no `X-RateLimit-*` headers. A `429` means back off and retry later; don't hot-loop.
- Errors: `401` → bad/missing token (`{"errors": "Unauthorized"}`); `404` → not found or not owned by this user (`{"errors": "Not found"}`); `422` → validation failure (`{"errors": {"field": ["message"]}}`, standard Rails shape); `402`/`429` → `{"info": "..."}`.
- State-machine actions (start/stop tracking, finish a task, calculate an estimation roadmap) are triggered via an **`event` query param** on a PUT/PATCH to the resource, not a body — see `references/`.
- Treat anything that creates, modifies, or deletes data as a mutation: confirm with the user before destructive calls (`DELETE`, or writes with unclear intent) using normal agent judgment — this skill doesn't need a special confirmation ritual beyond that.

## Picking a reference file

Load only what you need for the task at hand:

| File | Covers |
|---|---|
| `references/authentication.md` | Token header, subscription gate, rate limits, getting/regenerating a token |
| `references/projects.md` | Project CRUD, fields, `project_type` enum |
| `references/tasks.md` | Task CRUD, nesting under projects, `tracking` endpoint, start/finish events, **known API bug** with unsupported events |
| `references/activities.md` | Activity CRUD, start/stop tracking events |
| `references/goals.md` | Goal CRUD, user vs. project goals, **`begin_date` field correction** (not `month`) |
| `references/time-entries.md` | Time entry CRUD, attaching to a task/activity |
| `references/estimations-and-reports.md` | Project estimations (roadmap calculation) and reports |
| `references/errors-and-limits.md` | Full error/status catalog, rate limiting, subscription gate details |

For building an SDK/integration rather than making a few calls, read `references/errors-and-limits.md` plus every resource file you'll wrap, and mirror the "Client Guidance" notes in each.

## Known discrepancies vs. documentation (verified against source, Oct 2026)

These are real bugs/doc drift in TimeMagic itself, not skill errors — warn the user if they hit one:

1. **Goals**: the documented `month` field does not exist on the model. The real field for both reading and writing is **`begin_date`**. `period` defaults to `week`, not `month`.
2. **Tasks**: `event=stop_tracking` and `event=start_without_tracking` are documented but **not implemented** for tasks via the API — only `event=start_tracking` and `event=finish` exist. Calling the unimplemented events raises a server error (500), not a clean validation error. Don't use them; if the user asks for "pause a task" there's currently no API equivalent — only `finish`.
3. **Projects**: `project_type` actually accepts `tech_startup`, `creator`, `salary`, `other`, `outsource` (docs only mention two of these).
4. **Tasks**: `GET /api/tasks` with no `project_id` is not supported — tasks must be listed via `GET /api/projects/:project_id/tasks`, or fetched individually via `GET /api/tasks/:id`, or via `GET /api/tasks/tracking` for active ones.

## Helper script

`scripts/timemagic_request.rb` is a small, dependency-free Ruby wrapper around `net/http` that sets auth headers, handles the request/response cycle, and pretty-prints JSON or surfaces API errors clearly. Use it for quick ad-hoc calls or as a reference implementation when writing a real integration; it is not required for simple one-off curl calls.
