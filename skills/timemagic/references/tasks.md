# Tasks

Belong to a project. Drive time tracking via workflow events.

## Fields

| Field | Type | Notes |
|---|---|---|
| `uuid` | string | |
| `name` | string, required | enforced at the model level |
| `description` | string, nullable | |
| `status` | string | `pending`, `in_progress`, `completed`, `archived` (only `start`/`complete` events are API-exposed, see below) |
| `task_type` | string | `default` or `permanent` |
| `data` | object, nullable | |
| `project_uuid` | string | |
| `created_at` / `updated_at` | string, ISO-8601 | |

## Endpoints

- `GET /api/projects/:project_id/tasks` — tasks for a project. **There is no `GET /api/tasks` collection endpoint** — always nest under a project, or use `:id`/`tracking` below.
- `GET /api/tasks/:uuid` — single task.
- `GET /api/tasks/tracking` — the user's tasks that currently have an active (running) time entry. Good for "what am I tracking right now?".
- `POST /api/projects/:project_id/tasks` — body `{"task": {"name": "...", "description": "...", "task_type": "default"}}`.
- `PUT /api/tasks/:uuid` — body `{"task": {...}}` for field updates, or use `event` (see below) for workflow transitions. Don't mix both in one call.
- `DELETE /api/tasks/:uuid` — `204 No Content`.

## Workflow events (`PUT /api/tasks/:uuid?event=<event>`, no body)

| Event | Effect |
|---|---|
| `start_tracking` | `pending → in_progress`, opens a running time entry. Max 2 tasks "in progress with time tracking" at once — a 3rd returns a 422 (`"Active tasks with time tracking limit is reached"`). |
| `start_without_tracking` | `pending → in_progress` without opening a time entry — use when the user wants a task marked active without the clock running. |
| `stop_tracking` | `in_progress → pending`, pauses without completing. Use for "pause this task" / "stop tracking X" when the user isn't done with it. |
| `finish` | Closes any open time entry (`end_time: now`) and marks the task `completed`. |

All four events are implemented and return the updated task on success, or a `422` with `{"errors": {...}}` on an invalid transition (e.g. `stop_tracking` on a task that isn't `in_progress`).

## Relationships

- Belongs to a `project` (`project_uuid`).
- Has many `time_entries` through the time-tracking workflow (`resource_type: "Task"`).
