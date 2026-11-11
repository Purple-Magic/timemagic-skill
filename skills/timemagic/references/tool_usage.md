# Tool usage (MCP vs. raw REST)

TimeMagic exposes the same capabilities two ways:

1. **Raw REST**, as documented in the other `references/*.md` files - a Bearer token against
   `https://<host>/api`. This is what Claude Code/Codex use when you've set `TIMEMAGIC_API_TOKEN`
   and no MCP server is configured.
2. **MCP**, at `POST https://<host>/api/mcp` (same Bearer token, same account, same rate limit and
   subscription rules as the REST API - this is a transport choice, not a different account or a
   different set of permissions). Configure it as an MCP server in Claude Code/Codex if you'd
   rather have typed tool calls than hand-built HTTP requests.

The workflow guidance in `references/workflows.md` applies identically either way - it describes
*what to do*, independent of *how the call is shaped*. The table below maps MCP tool names to
their REST equivalent, for readers coming from one side or the other.

| MCP tool | REST equivalent |
|---|---|
| `list_projects` | `GET /api/projects` |
| `search_projects` | `GET /api/projects` + client-side name filter |
| `get_project` | `GET /api/projects/:uuid` |
| `create_project` | `POST /api/projects` |
| `update_project` | `PUT /api/projects/:uuid` |
| `list_tasks` | `GET /api/projects/:project_id/tasks` (or `GET /api/tasks/:uuid` for one). Over MCP each task carries only a `has_ai_context` flag, not the text; REST returns the full `ai_context` |
| `search_tasks` | same, + client-side name filter (also `has_ai_context` only over MCP) |
| `get_task` | `GET /api/tasks/:uuid` (returns the full `ai_context`) |
| `create_task` | `POST /api/projects/:project_id/tasks` (optional `ai_context`) |
| `update_task` | `PUT /api/tasks/:uuid` (`ai_context`: omit = keep, string = replace, empty string = clear) |
| `start_tracking` / `start_without_tracking` / `stop_tracking` / `switch_tracking` / `complete_task` | `PUT /api/tasks/:uuid?event=start_tracking` / `start_without_tracking` / `stop_tracking` / `switch_tracking` / `finish` |
| `get_current_activity` | `GET /api/tasks/tracking` |
| `list_activities` | `GET /api/activities` |
| `create_activity` | `POST /api/activities` |
| `start_timer` / `stop_timer` | `PUT /api/activities/:uuid?event=start_tracking` / `stop_tracking` |
| `log_time` | `POST /api/time_entries` |
| `get_week_goal` / `get_month_goal` | `GET /api/goals` + client-side `period` filter |
| `get_goal_progress` | no single REST equivalent yet - combine `GET /api/goals` with the resource's time entries |
| `update_goal` | `POST /api/goals` or `PUT /api/goals/:uuid` |
| `get_daily_report` | no single REST equivalent yet - combine `GET /api/time_entries` for the day with `GET /api/tasks`/`GET /api/projects` to group by project/task |
| `list_trash` | `GET /api/trash` (filters `type`, `project_uuid`, `query`, `page`, `per_page`; read-only) |
| `get_trashed_item` | `GET /api/trash/:type/:uuid` (read-only; a deleted task includes `description` and `ai_context`) |
| `export_trashed_task` | `GET /api/trash/task/:uuid/export` (read-only; `?variant=mcp` for the MCP tool-result shape; over MCP also returns `structuredContent`) |
| `restore_trashed_item` | `POST /api/trash/:type/:uuid/restore` (changes data - only on the user's explicit request; recreating has no tool: export, then `search_tasks` + `create_task`) |
| `submit_feature_request` | `POST /api/feature_requests` (list/get/update/delete: `GET /api/feature_requests[/:uuid]`, `PUT`/`DELETE /api/feature_requests/:uuid` - REST only, no MCP tool) |

An MCP tool call that fails returns the same error shapes as the REST API (`{"errors": ...}` for
`422`, not-found, etc.) inside the tool result, rather than a transport-level error - check the
result content before assuming success.

PubMagic tools (restricted: listed only for users TimeMagic has allowed; see `references/pubmagic.md` for the safety rules - publish only after explicit approval):

| MCP tool | REST equivalent |
|---|---|
| `list_pubmagic_accounts` | `GET /api/pubmagic/accounts` (never returns credentials) |
| `list_pubmagic_media_assets` | `GET /api/pubmagic/media_assets` |
| `create_pubmagic_media_asset` | `POST /api/pubmagic/media_assets` (base64, max 25 MB over MCP; multipart over REST) |
| `list_pubmagic_publications` | `GET /api/pubmagic/publications?status=` |
| `get_pubmagic_publication` | `GET /api/pubmagic/publications/:id` |
| `create_pubmagic_publication` | `POST /api/pubmagic/publications` (draft only; nothing is sent to YouTube; optional preview image: `thumbnail_base64` + `thumbnail_content_type`, REST: multipart `thumbnail`) |
| `update_pubmagic_publication` | `PATCH /api/pubmagic/publications/:id` (draft/failed only; can add or replace the preview image) |
| `request_pubmagic_publication` | `POST /api/pubmagic/publications/:id/publish` (preview unless `confirm: true`; `allow_duplicate` for reposts) |
