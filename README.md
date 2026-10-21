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

To update later:

```bash
claude plugin marketplace update ez-starter-kit
```

## Skills

| Skill | What it does |
|---|---|
| `/ez:next-session [topic]` | Ends a session with a handoff file (done · open · blocked on you · env/ops · proposed order) and a ready-to-paste prompt for the next session. Works with a single repo or a multi-repo workspace. |
| `/ez:clear-next-session [days=7] [--all] [--dry-run]` | Cleans up old handoffs: deletes every handoff older than `days` (the newest too, once nothing has been updated for that long) and superseded ones whose PRs are all merged/closed; open items carry over into the handoff that stays. Works without git. |

## Layout

```
.claude-plugin/
  plugin.json        # plugin name "ez" → /ez:* namespace
  marketplace.json   # lets others install it with `plugin marketplace add`
skills/
  <skill>/SKILL.md   # one folder per skill, plus any scripts it bundles
```
