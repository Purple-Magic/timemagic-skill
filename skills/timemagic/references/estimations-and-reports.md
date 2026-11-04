# Estimations

Build a time/roadmap estimate from a set of a project's tasks.

## Fields

| Field | Type | Notes |
|---|---|---|
| `uuid` | string | |
| `title` | string, required | |
| `description` | string, nullable | |
| `starts_at` / `ends_at` | string, ISO-8601 date, nullable | |
| `roadmap_state` | string | `idle`, `calculating`, `calculated` |
| `data` | object, nullable | |
| `project_uuid` | string | |
| `task_uuids` | array of strings | tasks included in the estimation |
| `created_at` / `updated_at` | string, ISO-8601 | |

## Where information goes

Per-task information (description, deliverables, acceptance criteria, dependencies, hours, price)
belongs in the **tasks**, not in the estimation. Hours and prices go in `task.estimation`; the
page and `data` read them from there, not from the description. The estimation `description` is only for things
common to the whole estimation (scope, rate/currency, total, external costs, exclusions,
assumptions). See `workflows.md` → "Creating estimations".

## Endpoints

- `GET /api/projects/:project_id/estimations` — list for a project.
- `GET /api/estimations/:uuid` — single estimation.
- `POST /api/projects/:project_id/estimations` — body `{"estimation": {"title": "...", "description": "...", "starts_at": "2025-10-01", "ends_at": "2025-10-15", "task_uuids": ["<task_uuid>"]}}`.
- `PUT /api/estimations/:uuid` — partial field updates: only the keys you send change, and `task_uuids`, when sent, replaces the whole set (`[]` unlinks all). `data` is recomputed by the server and is not writable. Or `?event=calculate_roadmap` (no body) to trigger calculation.
  - Requires `starts_at`, `ends_at`, at least one task, and the project to have `working_hours_per_day` set — otherwise `422` (`"Estimation roadmap cannot be calculated"`).
- `DELETE /api/estimations/:uuid` — `204 No Content`.

---

# Reports

Summarize logged time over a date range for a project, optionally scoped to specific tasks.

## Fields

| Field | Type | Notes |
|---|---|---|
| `uuid` | string | |
| `title` | string, nullable | |
| `description` | string, nullable | |
| `begin_date` / `end_date` | string, ISO-8601, required | |
| `data` | object, nullable | |
| `project_uuid` | string | |
| `selected_task_uuids` | array of strings | when present, limits the report to these tasks |
| `excluded_task_uuids` | array of strings | excluded from the report |
| `created_at` / `updated_at` | string, ISO-8601 | |

## Endpoints

- `GET /api/projects/:project_id/reports` — list for a project.
- `GET /api/reports/:uuid` — single report.
- `POST /api/projects/:project_id/reports` — body `{"report": {"title": "...", "begin_date": "2025-10-01", "end_date": "2025-10-07", "selected_task_uuids": [...], "excluded_task_uuids": [...]}}`.
- `PUT /api/reports/:uuid` — field updates.
- `DELETE /api/reports/:uuid` — `204 No Content`.
