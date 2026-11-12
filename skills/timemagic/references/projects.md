# Projects

Top-level container for tasks, estimations, and reports; can also own goals.

## Fields

| Field | Type | Notes |
|---|---|---|
| `uuid` | string | identifier |
| `name` | string | not enforced required at the model level despite docs implying it — send it anyway |
| `description` | string, nullable | |
| `project_type` | string | one of `tech_startup`, `creator`, `salary`, `other`, `outsource` (default `other`) |
| `rate_cents` | integer, nullable | |
| `rate_currency` | string, nullable | e.g. `"USD"` |
| `identifier_prefix` | string | three uppercase letters A-Z used in task identifiers (`DEV`). Generated from the name on creation (`Development` → `DEV`, collisions get another meaningful prefix), unique per user, never changed by a rename. Writable: `"identifier_prefix": "ENG"` (normalised to upper case); invalid or taken → `422` `{"errors": {"identifier_prefix": [...]}}`. Changing it renames every task identifier (`DEV-1` → `ENG-1`); old ones keep resolving and the old prefix stays reserved for this project |
| `show_task_identifiers` | boolean | web UI preference, default `true`. Writable. Only hides identifiers in the app's screens; API/MCP always return them and no numbering changes |
| `created_at` / `updated_at` | string, ISO-8601 | |

## Endpoints

- `GET /api/projects` — all projects owned by the user. No pagination or filters.
- `GET /api/projects/:uuid` — single project (the three-letter prefix works in place of the uuid: `GET /api/projects/DEV`).
- `POST /api/projects` — body `{"project": {"name": "...", "description": "...", "project_type": "other", "rate_cents": 5000, "rate_currency": "USD"}}` → `201` with the created project.
- `PUT /api/projects/:uuid` — same shape, partial updates allowed.
- `DELETE /api/projects/:uuid` — `204 No Content`. Deleting a project cascades to its tasks/estimations/reports — confirm with the user first.

## Relationships

- Has many `tasks`, `estimations`, `reports`.
- Can have `goals` attached (`goalable_type: "Project"`) — see `goals.md`.
