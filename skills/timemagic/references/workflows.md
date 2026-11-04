# Workflows

How to use the TimeMagic resources well, not just what they are. This file is the canonical
source for TimeMagic AI behavior - it's read by Claude/Codex via this skill, and also by
TimeMagic's own assistant (Bot Leopold, in both the web chat and Telegram) through a
version-pinned copy of this same repository. Fix a rule here once; every client picks it up.

## Search before you create

Before `create_project`/`POST /api/projects` or `create_task`/`POST .../tasks`, search existing
projects/tasks for a name match first (`search_projects`/`search_tasks`, or a `GET` + client-side
filter if you're not using MCP). If a close match exists, ask the user whether they meant that one
instead of silently creating a duplicate - unless they've explicitly said "make a new one anyway".

This applies per-request, not just once per conversation: re-search for each new entity the user
names, even if you already listed projects/tasks earlier in the conversation and nothing in your
tool access tells you data hasn't changed since.

## Resolving ambiguous references

"Start working on the API" when three tasks contain "API" is ambiguous. Don't guess:

1. Search by the given text.
2. Zero matches: say so, offer to create it (see above).
3. One match: confirm briefly only if the name match is partial/fuzzy; otherwise just act.
4. Multiple matches: list them (name + project) and ask which one, rather than picking the most
   recently created/most recently tracked as a silent default.

Track entities named earlier in the same conversation turn - "stop tracking it" after "start
working on the API docs task" refers back to that same task, not a new search.

## Natural-language durations and times

Parse phrases like "47 minutes", "half an hour", "from 2 to 3:30pm", "yesterday afternoon" into
the API's `begin_time`/`end_time`/`duration` fields yourself before calling the API - the API
takes ISO-8601 datetimes/seconds, not free text. When only a duration is given with no explicit
time, assume "ending now" (`end_time` = now, `begin_time` = now - duration) unless the user's
phrasing implies a different period (e.g. "yesterday I worked 47 minutes on X").

## Creating estimations

Task-specific information lives in the **tasks**; the estimation holds only what is common to the
whole estimation. Never duplicate per-task content in the estimation description.

1. Search-before-create applies (see above): check existing tasks and estimations in the project
   (including similarly-titled ones) first, and reuse matching tasks instead of duplicating them.
2. Create one task per piece of work (`POST /api/projects/:project_id/tasks`). Put everything about
   that piece of work in the task itself: description, deliverables, acceptance criteria,
   dependencies, and its hours and price (the API has no structured estimate fields for tasks, so
   write them in the task description, e.g. `Оценка: 3 ч — $72.`).
3. Create the estimation (`POST /api/projects/:project_id/estimations`) with `task_uuids` linking
   those tasks. Its `description` holds only estimation-wide things: scope/purpose, currency and
   rate, overall total, external costs, exclusions, assumptions, risks, and any coefficients. Do
   **not** list the tasks, their hours/prices, deliverables or acceptance criteria there. A one-line
   pointer such as "details are in the task descriptions" is fine.
4. Verify by reading the estimation back: it belongs to the right project, links every task, and
   the task hours/prices sum to the stated total.
5. When updating an estimation with `PUT`, always send the full set of fields you want to keep
   (`title`, `description`, `task_uuids`, dates). A partial body containing only `description` was
   observed to reset the title and clear `task_uuids`; read the result back and restore if needed.

## Starting and stopping work

- "Start working on X" / "start tracking X": resolve X (see above), then start tracking.
  Tasks only support one tracking slot; if the account is already tracking two tasks (the
  server-enforced limit), tell the user instead of silently stopping something for them.
- "Switch to X" / "stop Y and start X" / "work on X instead": use the `switch_tracking` event on
  X directly, rather than issuing a separate `stop_tracking` on the old task followed by
  `start_tracking` on the new one - it's one call and avoids a race where the old task's entry
  and the new one briefly overlap or fail independently. It stops whichever task is currently
  tracking (if any) and starts X. Only fall back to the manual two-call sequence for a project
  with `allow_parallel_tasks` where the user explicitly wants both running at once.
- "Stop tracking" / "I'm done with X for now" (not finished, just pausing): use the stop/pause
  event, not finish/complete - those are different and not interchangeable.
- "I finished X" / "mark X done": use the complete/finish event. This ends any open time entry
  automatically - don't also try to log time manually for the same task in the same request.
- "I worked on X for 47 minutes" (after the fact, no live timer involved): log a time entry
  directly rather than starting and immediately stopping a timer - the two produce different,
  both-valid records, but the direct log is what the user is asking for and avoids a timer
  blip appearing in their history.

## Daily reports

"How much did I work today?" / "what did I do yesterday?": use `get_daily_report` for the given
date rather than manually summing time entries yourself - it already groups by project/task.
Default to today when no date is given.

## Feedback and feature requests

"I wish TimeMagic could..." / "can you tell the team..." / "report a bug" (a request *about*
TimeMagic itself, not a task/project/time action): use `submit_feature_request` with the user's
own words as `description`, then confirm it was sent. Don't silently drop this kind of message as
small talk, and don't require a minimum length before offering to submit it.

## TimeMagic bugs and missing features

Offer to file a feature request (or bug report) when either of these happens:

- **You find a bug in TimeMagic itself**: API and public page/UI disagree, a write silently
  changes other fields, a response contradicts the docs, a documented field is missing, a record
  changes without any request from you, etc. (Do not offer this for ordinary user errors such as
  a bad token or a validation error caused by your own request.)
- **The user wants something TimeMagic cannot do**: a field, endpoint, workflow or UI behaviour
  that doesn't exist (for example structured hour/price fields on tasks).

What to do:

1. Finish or safely stop the current task first; say plainly what happened and what you verified.
2. **Ask the user** whether they want to submit a feature request containing the finding. Never
   submit one without their yes.
3. On yes, use `submit_feature_request` if the MCP tool is available, with the user's own wording
   plus the details. There is no REST equivalent; without MCP, write the report as a ready-to-paste
   prompt or issue text instead (see `tool_usage.md`) and hand it to the user.
4. Make the report self-contained: real IDs (project, estimation/task/etc. UUIDs), expected vs.
   actual behaviour, a timeline of the requests you made (and anything that changed without
   them), API-vs-UI differences, and how to reproduce. No tokens or other secrets.

## Duplicate / already-exists requests

"Create X" when X already exists by name: treat like any other search-before-create case - tell
the user it already exists and ask if they want to use the existing one, update it, or really
create a second one with the same name (projects/tasks don't enforce name uniqueness, so a
duplicate is possible but rarely what's wanted).

## Destructive actions

Deleting a project/task/activity/time entry, or any action with "this can't be undone" character,
needs an explicit confirmation step from the user before the call - describe what will be deleted
and wait for a yes, except when the user's own message already states the deletion unambiguously
and completely (e.g. "delete the 'Old Draft' task in Website Redesign" naming both the exact
entity and the action - don't re-confirm a request that was already explicit just to be safe).

## Goals

- A "goal" is scoped to either the user (overall) or a single project - always check which the
  user means. "How's my goal going?" defaults to the user's own current-period goal; "how's the
  TimeMagic project goal doing?" is project-scoped.
- When reporting goal progress, state it in the same units/period the goal itself uses (week vs.
  month) - don't silently convert.
- Setting a goal ("set my weekly goal to 20 hours") replaces the current period's goal; it does
  not create an additional one for the same period.

## Composing multi-step requests

"Create a task to buy milk and start tracking it" is one user request spanning two tool calls
(create, then start tracking) - do both without asking for confirmation in between unless the
create step itself needed disambiguation/confirmation. Report the combined outcome once at the
end ("Created 'Buy milk' and started tracking it"), not as two separate narrations.

## After an action, say what actually happened

Confirm the concrete result (what was created/changed/started/stopped, with its name) rather than
a generic "Done!" - the user can't see the UI, so the confirmation is their only feedback.
