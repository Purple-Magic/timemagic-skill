# Time Entries

A logged span of time, optionally attached to a task or activity (`resource`).

## Fields

| Field | Type | Notes |
|---|---|---|
| `uuid` | string | |
| `begin_time` | string, ISO-8601, required | |
| `end_time` | string, ISO-8601, nullable | |
| `duration` | integer (seconds), nullable | computed/synced when `end_time` is set |
| `comment` | string, nullable | |
| `resource_type` | string | `"Activity"` or `"Task"` |
| `resource_uuid` | string | UUID of the attached activity/task |
| `created_at` / `updated_at` | string, ISO-8601 | |

## Endpoints

- `GET /api/time_entries` — all time entries for the user. No filters/pagination — if the user wants "today's" entries, fetch all and filter client-side by `begin_time`.
- `GET /api/time_entries/:uuid` — single entry.
- `POST /api/time_entries` — body:
  ```json
  {"time_entry": {"begin_time": "2025-10-01T09:00:00Z", "end_time": "2025-10-01T10:00:00Z", "comment": "...", "resource_type": "task", "resource_id": "<task_uuid>"}}
  ```
  - `resource_type` must be **lowercase** (`task` or `activity`) on write — the response later returns it capitalized (`Task`/`Activity`).
  - `resource_id` is optional. If given but it doesn't resolve to a resource owned by the user, the entry is created **without** a resource attached (silent fallback) rather than erroring — double-check `resource_uuid` in the response if attachment matters.
  - `resource_type`/`resource_id` can only be set at creation; `PUT` cannot re-attach a time entry to a different resource.
- `PUT /api/time_entries/:uuid` — body `{"time_entry": {"begin_time": "...", "end_time": "...", "comment": "..."}}`.
- `DELETE /api/time_entries/:uuid` — `204 No Content`.

## Relationships

- Belongs to a `Task` or `Activity` via polymorphic `resource`. Starting/finishing a task, or starting/stopping an activity, creates/closes time entries automatically (see `tasks.md`/`activities.md`) — manual `POST`/`PUT` here is for direct/retroactive logging.
