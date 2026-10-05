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
