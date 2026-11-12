# Payments

Money received by a project. Only **`creator`** (Crowdfunding) and **`outsource`** projects take payments - any other `project_type` answers `422` (`"Payments can only be added to creator and outsource projects"`). A payment created through the API is complete immediately and counts toward the project's revenue (when the project's revenue method is "Sum of payments").

## Fields

| Field | Type | Notes |
|---|---|---|
| `uuid` | string | |
| `project_uuid` | string | read-only |
| `payment_type` | string, required | `one_time_payment` or `monthly_subscription` |
| `amount` | number, required | major units (`49.5`), must be > 0. Responses also carry `amount_cents` (4950) |
| `amount_currency` | string, required | ISO code, e.g. `"USD"`; unknown code → `422` |
| `datetime` | string, ISO-8601 | **required for `one_time_payment`** - when it was paid |
| `subscribed_at` | string, date/ISO-8601 | **required for `monthly_subscription`** |
| `unsubscribed_at` | string, nullable | set when a subscription ends; must not be before `subscribed_at`. Empty = still active (billed monthly until today) |
| `source` | string | `Patreon`, `Boosty`, `Ko-fi`, `Buy Me a Coffee`, `Other`. Defaults to `Other` on creator projects; **outsource projects always store `client`** whatever you send |
| `filling_state` | string | `completed` for API-created payments; `incomplete` only for payments left half-filled in the web wizard (not counted in revenue) |
| `created_at` / `updated_at` | string, ISO-8601 | |

## Endpoints

- `GET /api/projects/:project_id/payments` - payments of the project (project uuid or three-letter prefix). Subscription required (GET rule).
- `POST /api/projects/:project_id/payments` → `201`
  - One-time: `{"payment": {"payment_type": "one_time_payment", "amount": 49.5, "amount_currency": "USD", "datetime": "2026-11-01T10:00:00Z", "source": "Patreon"}}`
  - Subscription: `{"payment": {"payment_type": "monthly_subscription", "amount": 10, "amount_currency": "USD", "subscribed_at": "2026-01-01", "source": "Boosty"}}`
- `GET /api/payments/:uuid`
- `PUT /api/payments/:uuid` - partial, e.g. `{"payment": {"unsubscribed_at": "2026-10-01"}}` to end a subscription.
- `DELETE /api/payments/:uuid` → `204`. The payment stops counting toward revenue - confirm with the user first.

Validation errors: `422 {"errors": {"amount": [...], "datetime": [...]}}`. Another user's project or payment is `404`.

## MCP

`list_payments(project_uuid)`, `get_payment(uuid)`, `create_payment(project_uuid, payment_type, amount, amount_currency, ...)`, `update_payment(uuid, ...)`, `delete_payment(uuid)` - same fields and rules as above.

## Agent guidance

- Check `project_type` first (`get_project`); do not try payments on `tech_startup`, `salary` or `other` projects - tell the user instead.
- List a project's payments before adding one, so the same payment is not recorded twice.
- Ask for the amount, currency and date if the user did not give them; never guess a currency.
- A subscription ending is an `update_payment` with `unsubscribed_at`, not a delete.
