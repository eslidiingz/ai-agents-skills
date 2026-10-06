# ez — Claude Code starter kit

Project-agnostic skills and agents for [Claude Code](https://claude.com/claude-code), packaged as the `ez` plugin.
Skills are invoked as `/ez:<skill>`.

## Install

From a clone:

```bash
claude plugin marketplace add /path/to/ai-agents-skills
claude plugin install ez@ez-starter-kit
```

Or straight from GitHub once pushed: `claude plugin marketplace add <owner>/ai-agents-skills`.

## Skills

| Skill | What it does |
|---|---|
| `/ez:next-session [topic]` | Ends a session with a handoff file (done · open · blocked on you · env/ops · proposed order) and a ready-to-paste prompt for the next session. Works with a single repo or a multi-repo workspace. |

## Layout

```
.claude-plugin/
  plugin.json        # plugin name "ez" → /ez:* namespace
  marketplace.json   # lets others install it with `plugin marketplace add`
skills/
  <skill>/SKILL.md   # one folder per skill, plus any scripts it bundles
```
