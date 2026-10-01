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
| `created_at` / `updated_at` | string, ISO-8601 | |

## Endpoints

- `GET /api/projects` — all projects owned by the user. No pagination or filters.
- `GET /api/projects/:uuid` — single project.
- `POST /api/projects` — body `{"project": {"name": "...", "description": "...", "project_type": "other", "rate_cents": 5000, "rate_currency": "USD"}}` → `201` with the created project.
- `PUT /api/projects/:uuid` — same shape, partial updates allowed.
- `DELETE /api/projects/:uuid` — `204 No Content`. Deleting a project cascades to its tasks/estimations/reports — confirm with the user first.

## Relationships

- Has many `tasks`, `estimations`, `reports`.
- Can have `goals` attached (`goalable_type: "Project"`) — see `goals.md`.
