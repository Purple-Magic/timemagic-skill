# Activities

Standalone trackable items, not tied to a project (e.g. "Reading", "Gym").

## Fields

| Field | Type | Notes |
|---|---|---|
| `uuid` | string | |
| `name` | string, required | |
| `activity_type` | string | `productive`, `leisure`, `other` (default `productive`) |
| `aasm_state` | string | `pending` or `in_progress` |
| `created_at` / `updated_at` | string, ISO-8601 | |

## Endpoints

- `GET /api/activities` — all activities for the user.
- `GET /api/activities/:uuid` — single activity.
- `POST /api/activities` — body `{"activity": {"name": "...", "activity_type": "productive"}}`.
- `PUT /api/activities/:uuid` — body `{"activity": {...}}` for field updates, or `event` for tracking.
- `DELETE /api/activities/:uuid` — `204 No Content`.

## Workflow events (`PUT /api/activities/:uuid?event=<event>`, no body)

| Event | Effect |
|---|---|
| `start_tracking` | `pending → in_progress`. |
| `stop_tracking` | `in_progress → pending`. (Unlike tasks, activities do support stop_tracking.) |

## Relationships

- Has many `time_entries` (`resource_type: "Activity"`).
