# Feature Requests

Belong to the authenticated user. Only `description` is writable; `status` is managed by the TimeMagic team and is read-only.

## Fields

| Field | Type | Notes |
|---|---|---|
| `uuid` | string | |
| `description` | string, required | |
| `status` | string, read-only | `on_review` (default), `accepted`, `planned`, `released` |
| `created_at` / `updated_at` | string, ISO-8601 | |

## Endpoints

- `GET /api/feature_requests` - the user's feature requests, newest first.
- `GET /api/feature_requests/:uuid` - single feature request.
- `POST /api/feature_requests` - body `{"feature_request": {"description": "..."}}`, returns `201`.
- `PUT /api/feature_requests/:uuid` - body `{"feature_request": {"description": "..."}}`. A `status` in the body is ignored.
- `DELETE /api/feature_requests/:uuid` - `204 No Content`.

Another user's request returns `404`. Deleting is irreversible from the client's point of view: list the
requests and confirm with the user before bulk-deleting ("delete all my feature requests").
