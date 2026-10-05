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
| `list_tasks` | `GET /api/projects/:project_id/tasks` (or `GET /api/tasks/:uuid` for one) |
| `search_tasks` | same, + client-side name filter |
| `get_task` | `GET /api/tasks/:uuid` |
| `create_task` | `POST /api/projects/:project_id/tasks` |
| `update_task` | `PUT /api/tasks/:uuid` |
| `start_tracking` / `stop_tracking` / `complete_task` | `PUT /api/tasks/:uuid?event=start_tracking` / `stop_tracking` / `finish` |
| `get_current_activity` | `GET /api/tasks/tracking` |
| `list_activities` | `GET /api/activities` |
| `create_activity` | `POST /api/activities` |
| `start_timer` / `stop_timer` | `PUT /api/activities/:uuid?event=start_tracking` / `stop_tracking` |
| `log_time` | `POST /api/time_entries` |
| `get_week_goal` / `get_month_goal` | `GET /api/goals` + client-side `period` filter |
| `get_goal_progress` | no single REST equivalent yet - combine `GET /api/goals` with the resource's time entries |
| `update_goal` | `POST /api/goals` or `PUT /api/goals/:uuid` |

An MCP tool call that fails returns the same error shapes as the REST API (`{"errors": ...}` for
`422`, not-found, etc.) inside the tool result, rather than a transport-level error - check the
result content before assuming success.
