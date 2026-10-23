# ez — Claude Code starter kit

Project-agnostic skills and agents for [Claude Code](https://claude.com/claude-code), packaged as the `ez` plugin.
Skills are invoked as `/ez:<skill>`.

## Install

Add the marketplace first, then install the plugin:

```bash
claude plugin marketplace add eslidiingz/ai-agents-skills
claude plugin install ez@ez-starter-kit
```

Start a new Claude Code session afterwards to pick up the skills.
Working from a local clone instead? Use the clone's path in place of `eslidiingz/ai-agents-skills`.

> `Plugin "ez" not found in marketplace "ez-starter-kit"` usually means the `marketplace add` step was skipped.

## Update

Refresh the marketplace, then update the plugin:

```bash
claude plugin marketplace update ez-starter-kit
claude plugin update ez@ez-starter-kit
```

Start a new Claude Code session afterwards to apply the update.
If the second command reports "already at the latest version", the plugin is up to date.

## Skills

| Skill | What it does |
|---|---|
| `/ez:next-session [topic]` | Ends a session with a handoff file (done · open · blocked on you · env/ops · proposed order) and a ready-to-paste prompt for the next session, then replaces the handoff it started from (open items carry over). Each stream of work keeps one handoff, so parallel sessions never overwrite each other. Works with a single repo or a multi-repo workspace. |
| `/ez:clear-next-session [days=7] [--all] [--dry-run]` | Cleans up old handoffs per stream: deletes every handoff older than `days` (a stream's newest too, once nobody has continued it that long) and superseded ones whose PRs are all merged/closed; open items carry over into the same stream's handoff that stays. Works without git. |

## Layout

```
.claude-plugin/
  plugin.json        # plugin name "ez" → /ez:* namespace
  marketplace.json   # lets others install it with `plugin marketplace add`
skills/
  <skill>/SKILL.md   # one folder per skill, plus any scripts it bundles
```
