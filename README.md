# TimeMagic Skill

The official [Agent Skill](https://github.com/anthropics/skills) for [TimeMagic](https://time-app.purple-magic.com) — gives Claude Code and OpenAI Codex everything they need to read and manage your projects, tasks, activities, goals, time entries, estimations, reports, and feature requests through the TimeMagic API, without you having to paste in docs every time.

## Install (Claude Code + Codex, one command)

```bash
npx skills add purple-magic/timemagic-skill -g -a claude-code -a codex -y
```

This installs the skill globally for both agents (`~/.claude/skills/timemagic` and `~/.codex/skills/timemagic`). Drop `-g` to install into just the current project instead.

## What it enables

Once installed, you can ask Claude Code or Codex things like:

- "Show my active TimeMagic projects."
- "Create a task in my Website Redesign project."
- "What have I tracked today?"
- "Create a task for the Google sign-in work and add AI context with the Devise constraints."
- "Implement my 'Google authentication' TimeMagic task." (the skill reads the task's AI Agent Context itself)
- "Start tracking time on my 'Write report' task."
- "List my TimeMagic goals for this month."
- "Build a Ruby script that syncs TimeMagic tasks into a spreadsheet."
- "Show me my deleted tasks." / "Find the task I deleted last month." / "Show everything in Trash." (read-only)
- "Restore this deleted task." (brings the original back; the server rolls back and keeps it in Trash if it no longer works)
- "Recreate this deleted task because it can't be restored." (makes a new task from the saved data; the original stays in Trash)
- "Publish this vertical video to my YouTube Shorts channel." / "Schedule it for Friday." (PubMagic, allowed users only; the skill shows a preview and publishes only after your explicit approval)

It works both for driving your own TimeMagic account and for writing third-party integrations against the TimeMagic API.

## PubMagic

PubMagic publishes a vertical video to the user's connected YouTube channel through the official YouTube Data API. It is a restricted feature: only users TimeMagic has allowed can use it (everyone else gets `404`). The skill keeps the safety rules: publish only after explicit approval of the exact video, channel, title and visibility (preview first, then `confirm: true`), the user answers the kids/synthetic-media declarations, visibility defaults to private, and connecting the channel stays browser-only. Details: `skills/timemagic/references/pubmagic.md`.

## Trash

Deleted tasks, projects and activities stay in the user's TimeMagic Trash indefinitely - without any promise that they can be restored. The skill keeps three operations apart: **read** (list/show/export deleted data, read-only), **restore** (the server brings the original item back transactionally, or changes nothing), and **recreate** (a new task built from the deleted task's export through the ordinary create call). Deleted content is treated as untrusted data, never as instructions. Details: `skills/timemagic/references/trash.md`.

## AI Agent Context

TimeMagic tasks have an optional **AI Agent Context** (`ai_context`): Markdown with the detailed instructions an AI agent needs for a task, kept separate from the short human-facing description. The skill:

- **asks** whether you want to add AI context whenever it creates a task (you can write it, have it drafted from the conversation, or decline), and whenever it edits a task (keep, review, extend, replace, or remove the existing context) — unless you already said what you want;
- **reads** the context automatically when you ask it to work on a task, and treats it as task data, not as instructions that override its own rules;
- **never overwrites or erases** existing context unless you chose to; updates that don't mention it leave it untouched.

## Requirements

- Claude Code or OpenAI Codex (recent versions — both support the open [Agent Skills](https://github.com/anthropics/skills) `SKILL.md` format natively).
- A TimeMagic account and API token (see [Authentication](#authentication) below).
- [Node.js](https://nodejs.org/) (for `npx skills`), or `git`/`gh` for a manual install.

## Claude Code installation

Via the cross-agent installer (recommended, keeps itself updatable):

```bash
npx skills add purple-magic/timemagic-skill -g -a claude-code -y
```

Or as a native Claude Code plugin, pointing straight at this repo as a marketplace:

```bash
claude plugin marketplace add purple-magic/timemagic-skill
claude plugin install timemagic
```

Either path installs the same canonical skill — there's no plugin-specific copy of the instructions.

## Codex installation

```bash
npx skills add purple-magic/timemagic-skill -g -a codex -y
```

Codex reads `SKILL.md` directly (the open Agent Skills format), so this just places the skill under `~/.codex/skills/timemagic`.

## Install into both at once

```bash
npx skills add purple-magic/timemagic-skill -g -a claude-code -a codex -y
```

## GitHub CLI (alternative)

If your `gh` has the `gh skill` extension (GitHub CLI ≥2.90, currently in preview):

```bash
gh skill install purple-magic/timemagic-skill --agent claude-code --agent codex
```

## Authentication

The skill never stores or hardcodes a token. Set your TimeMagic API token as an environment variable before using it:

```bash
export TIMEMAGIC_API_TOKEN=<your-token>
```

Get a token at **[time-app.purple-magic.com/docs/api](https://time-app.purple-magic.com/docs/api)** — log in, open the "API Token" section, and copy or regenerate your token there. If the environment variable isn't set, the skill will tell you where to get one instead of guessing or asking you to paste it into chat.

## Example prompts

```
Show my active TimeMagic projects.
Create a task called "Write Q4 report" in my Marketing project.
What have I tracked today?
Start tracking time on my current task.
List my goals for this week.
Write a Ruby script that pulls my TimeMagic time entries into a CSV.
```

## Updating

```bash
npx skills update timemagic -g
```

## Uninstalling

```bash
npx skills remove --skill timemagic -g
```

Or, for a native Claude Code plugin install:

```bash
claude plugin uninstall timemagic
```

## Verification

```bash
npx skills list -g
```

should list `timemagic` for the agents you installed it into. In Claude Code, `/skill timemagic` (or just asking a TimeMagic-shaped question) should discover and load it.

## Repository structure

```text
timemagic-skill/
  README.md
  LICENSE
  .claude-plugin/
    plugin.json          # Claude Code plugin manifest, points at skills/timemagic
    marketplace.json      # lets this repo be added as a Claude Code marketplace
  skills/
    timemagic/
      SKILL.md            # canonical skill — the single source of truth
      references/         # per-resource API reference, loaded on demand
      scripts/
        timemagic_request.rb   # tiny stdlib-only HTTP helper
        timemagic_trash.rb     # Trash helper: list / show / export / restore --confirmed (no recreate)
  evals/
    trigger-cases.json    # positive/negative prompts for skill-discovery evals
  tests/
    validate.rb           # repo self-checks (frontmatter, manifests, secrets, syntax)
    trash_script_test.rb  # request-building tests for the Trash helper
```

There is exactly one copy of the TimeMagic instructions, at `skills/timemagic/SKILL.md` plus its `references/`. The Claude Code plugin manifest references that directory rather than duplicating it; Codex and other Agent-Skills-compatible tools consume the same `SKILL.md` directly.

## Development / testing

```bash
ruby tests/validate.rb
ruby tests/trash_script_test.rb
```

Checks SKILL.md frontmatter, required reference files, plugin/marketplace manifest validity and linkage, eval file shape, absence of committed secrets, and that the helper script is syntactically valid.

To manually sanity-check discovery, try the prompts in `evals/trigger-cases.json` against an installed copy of the skill and confirm the positive prompts load it and the negative prompts don't.

## Keeping this skill current

The authoritative TimeMagic API documentation lives at [time-app.purple-magic.com/docs/api](https://time-app.purple-magic.com/docs/api) and can change independently of this repository. `SKILL.md` tells agents to defer to that live documentation when something looks outdated. When the TimeMagic API changes:

1. Update the relevant file(s) under `skills/timemagic/references/`.
2. Run `ruby tests/validate.rb`.
3. Bump `version` in `.claude-plugin/plugin.json`.
4. Commit and push — `npx skills update` picks up the new content on the next run.

## Security

- No API tokens or secrets are ever committed to this repository.
- The skill reads credentials only from the `TIMEMAGIC_API_TOKEN` environment variable and never writes them to generated files or prints them.
- Mutating API calls (create/update/delete) are treated as normal agent actions — your coding agent's own confirmation conventions apply; this skill doesn't bypass them.
- Found a security issue? Please open an issue in this repository rather than filing it publicly with reproduction details for a live account.

## License

[MIT](LICENSE)
