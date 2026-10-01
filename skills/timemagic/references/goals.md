# Goals

Can belong to the user directly, or to a project (polymorphic `goalable`).

## Fields

| Field | Type | Notes |
|---|---|---|
| `uuid` | string | |
| `text` | string, required | |
| `period` | string | `week` (default) or `month` |
| `begin_date` | string, ISO-8601 date, required | **The published docs call this `month` — that field does not exist on the model and is silently dropped from responses. Always use `begin_date` for both reads and writes.** Normalized to the start of the period (start of week/month) on save. |
| `goalable_type` | string | `"User"` or `"Project"` |
| `goalable_uuid` | string | present when attached to a user or project |
| `created_at` / `updated_at` | string, ISO-8601 | |

Uniqueness: one goal per `(goalable, period, begin_date)` — creating a duplicate returns `422`.

## Endpoints

- `GET /api/goals` — goals for the user. Add `?project_id=<project_uuid>` to scope to a project's goals.
- `GET /api/goals/:uuid` — single goal (owned by the user directly, or via a project they own).
- `POST /api/goals`
  - User goal: `{"goal": {"text": "...", "period": "month", "begin_date": "2025-10-01"}}`
  - Project goal: add `"project_id": "<project_uuid>"` inside the `goal` object.
- `PUT /api/goals/:uuid` — body `{"goal": {...}}`.
- `DELETE /api/goals/:uuid` — `204 No Content`.
