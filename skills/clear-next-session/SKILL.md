---
name: clear-next-session
description: Clean up old next-session handoff files written by /ez:next-session — per stream of work, delete every handoff older than the age threshold (the stream's newest too, once nothing has been updated for that long) and superseded ones whose PRs are all merged/closed, and never lose an open item that didn't carry over. Use when the user says "clear next-session", "clean up handoffs", "ล้าง handoff", "ลบ next-session เก่า". Works with or without git.
argument-hint: "[days=7] [--all] [--dry-run]"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# Clear old handoffs

Remove handoff files that no longer help the next session, without losing any open work.

Reply in the language the user has been using in this session.

**Arguments** (all optional):
- `days` — age threshold, default **7**.
- `--all` — delete each stream's newest handoff too, even when it is recent.
- `--dry-run` — show the plan and stop without changing anything.

No confirmation step: once the rules below have decided, delete. The carry-over step is what keeps open work safe.

## 1) Find handoffs

Handoffs live wherever `/ez:next-session` wrote them:
- the session's persistent memory directory, if the system prompt names one;
- `<project root>/.claude/handoffs/`.

Run the bundled scanner from this skill's base directory on every location that exists:

```bash
bash "<skill-base-dir>/scripts/scan.sh" "<memory dir>" "<project root>/.claude/handoffs"
```

For each `next-session-*.md`, grouped by **stream** (one line of work: `stream:` in the frontmatter, else the slug in `next-session-<date>-<stream>.md`, else `default`) and newest first, it prints the date, age in days, whether it is the newest in its stream, the state of every PR written as `owner/repo#N` or a GitHub PR URL (`MERGED` / `CLOSED` / `OPEN` / `UNKNOWN`), and bare `#N` refs that can't be checked.
No git or `gh`? PR states come back `UNKNOWN` and the rules below fall back to age and supersession only.

No handoff files anywhere → say so and stop.

## 2) Decide per file

Apply in order, first match wins:

| # | Condition | Verdict |
|---|---|---|
| 1 | older than `days` — the stream's newest file included | **clear** |
| 2 | newest file in its stream (and no `--all`) | **keep** |
| 3 | every PR ref is `MERGED` or `CLOSED`, and there is at least one | **clear** |
| 4 | anything else (open PR, unknown state, no refs, within `days`) | **keep** |

A file within `days` with no PR refs is kept on purpose: without evidence, recency wins.
When even a stream's newest handoff is older than `days`, nobody has continued that stream for that long and the whole stream is cleared. Other streams are judged on their own.

## 3) Carry-over check — before clearing anything

Read each file marked **clear** and the kept handoff **of the same stream**. List every item in a clear-file that is still open (🟡 / 🔴 / ⏸ / ⚠️ / 🧪) and whose ID does not appear in that kept handoff. These are **orphans**: work that would disappear with the file.

Drop an orphan only with evidence it is finished (PR merged, item marked done in a later handoff, the user said so this session). Carry every other orphan over: append it to the same stream's kept handoff under `## Carried over from <date>`, unchanged. Don't ask.

When no handoff of that stream is kept (all older than `days`, or `--all`), there is nothing to carry into — never carry into another stream: list the orphans in the reply, one line each, so the user sees what was dropped, then delete.

## 4) Act

On `--dry-run`, show the table from step 5 as a plan and stop.

Otherwise carry orphans over first, then delete the cleared files. Never touch files other than `next-session-*.md`.

In a memory directory, also update `MEMORY.md`: remove the index lines of cleared files, and if the kept handoff's line says `(superseded …)` while nothing newer exists, remove that note.

## 5) Reply

One table — stream · file · date · age · kept/deleted · reason — then at most 3 lines: orphans carried over · orphans dropped (with the evidence, or "no handoff left to carry into" followed by the list).
