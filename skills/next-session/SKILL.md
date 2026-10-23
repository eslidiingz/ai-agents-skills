---
name: next-session
description: Close the current session with a handoff note — what got done, what is still open, what is blocked on the user, and what the next session should do — plus a ready-to-paste starter prompt for the next session. Use when the user says "next session", "handoff", "wrap up", "ส่งต่องาน", "ปิด session", or is stopping because of cost, time, or a nearly full context window. Works in any project, single repo or multi-repo.
argument-hint: "[short topic of this session (optional)]"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# Next-session handoff

Produce two things, and nothing else:
1. **One handoff file** that a fresh session can read to pick up exactly where this one stopped.
2. **One starter prompt** the user can paste into the next session.

Reply in the language the user has been using in this session.

Do this yourself in the main session: no subagents, no new work, no commits, no pushes. If something is half-done, record it — don't finish it now.

## 1) Gather facts — run once

Run the bundled script from this skill's base directory, against the project root:

```bash
bash "<skill-base-dir>/scripts/gather.sh" "<project root>"
```

It reports, for the root repo and every git repo one level below it: branch, base branch, ahead/behind, unpushed commits, uncommitted files grouped by area, stashes, worktrees, and your open / merged-today PRs (when `gh` is available). It also lists previous handoffs in `.claude/handoffs/`.
Set `HANDOFF_BASE=origin/<branch>` if the project integrates on a branch the script can't guess, and `HANDOFF_FETCH=0` when offline.

Also check, when they apply:
- the **predecessor**: the handoff this session was told to read when it started (the path in the starter prompt that opened it). Read it — this handoff replaces it, so its open items must carry over (step 3). No predecessor in this conversation → this is a new stream; replace nothing. Other `next-session-*.md` files belong to other sessions: leave them alone;
- running dev servers or background tasks (e.g. `preview_list`, background shells) — which are running, which you stopped;
- project plan / task files the session worked from (a `PLAN.md`, `TODO.md`, issue tracker IDs, etc.).

**Never guess.** Unknown results are written as unknown:
- a subagent or job that hasn't reported back → "still running / result unknown";
- tests a subagent ran → "agent reported …", not "tests pass";
- anything nobody checked in the real app → "not verified in the app".

## 2) Classify

Give every work item an ID — the project's own (plan step, ticket, issue #) if it has one, otherwise a short slug — and put it in exactly one category:

| Category | What goes in it |
|---|---|
| ✅ Done | merged (PR as `owner/repo#N` + merge sha) · deployed / migrated (env + what) |
| 🟡 Done in code, not shipped | main files/dirs · reported test results · verified in the app or not · **the next step that can be taken immediately** |
| 🔴 Blocked on user | each question **with a recommended answer** (so the user can reply "as recommended") · things only the user can do by hand (permissions, credentials, accounts, devices) |
| ⏸ Not started | queued work + what must be true before it starts |
| ⚠️ Env / ops | new env vars + defaults · deploy order · local config files edited (and where the original is backed up) · servers stopped · migrations run / pending per environment |
| 🧪 Test data / side effects | records created or modified in shared environments, and whether they were restored |
| 🔀 Mixed files | files touched by more than one work item ⇒ must be split by hunk at commit time |

Write every PR as `owner/repo#N` (or its full URL), never a bare `#N`, so the next session can check whether it merged.

Decisions the user made this session go on the relevant item with the date and the note **"decided — don't ask again"**.

Leave out empty categories.

## 3) Write the handoff file

**Where:**
- If this session has a persistent memory directory (the system prompt names one), write it there as a `project` memory and add an index line to that directory's `MEMORY.md`.
- Otherwise write to `<project root>/.claude/handoffs/`. If that path isn't git-ignored, tell the user so they can decide whether to ignore it — don't edit `.gitignore` yourself.

**Stream:** one line of work, named by a short kebab-case slug. Continuing from a predecessor → reuse its stream. New stream → derive the slug from the topic argument or the session's main work (e.g. `payment-refund`). Several sessions can run at once; each stream keeps its own handoff, so they never overwrite each other.

**Name:** `next-session-<YYYY-MM-DD>-<stream>.md`. If that name is taken, append `-2`, `-3`, … Never overwrite an existing handoff — write the new one first, then delete the predecessor (below).

**Carry over before replacing:** every open item (🟡 / 🔴 / ⏸ / ⚠️ / 🧪) in the predecessor must land in the new handoff — under its own category, with its status updated from this session's facts. Drop an item only with evidence it is finished (PR merged, done this session, the user said so), and list it under ✅ Done.

**Template:**

```markdown
---
name: next-session-<YYYY-MM-DD>-<stream>
description: Open work in stream <stream> after the <date> session (<topic>) — replaces <predecessor file or "none">; status per item, questions for the user, proposed order
metadata:
  type: project
  stream: <stream>
---

Session <date> · stream <stream> · <topic> · ended because <cost / end of day / context full> · replaces: <predecessor file name or "none">

## ✅ Done
## Status per item
| ID | Status | Next step |
|---|---|---|
## 🔴 Blocked on user (question → recommended answer)
## ⚠️ Env / ops
## 🧪 Test data / side effects
## 🔀 Mixed files to split by hunk
## Proposed order
1. … (🟢 can run in parallel / 🟡 must wait for the previous step)

**Why:** <why the work is being handed off>
**How to apply:** at the start of the next session read this file, then re-check `git status` and `git log <base>..HEAD` in each repo listed before acting; remove questions once answered.
```

**Then delete the predecessor** — only after the new file is written, and only that one file. If it is already gone (another session started from the same handoff and replaced it first), skip. Never delete any other handoff: they belong to other sessions.

In a memory directory, `MEMORY.md` gets one line per stream: replace the predecessor's line, or add one for a new stream — `- [Open work: <stream> after <date> → continue](next-session-<date>-<stream>.md) — <one-line highlight>`.

Each stream keeps exactly one handoff. Streams nobody continues are cleaned up by `/ez:clear-next-session`.

**Never write** secret values, tokens, passwords, OTPs, or real customer personal data. Env var *names* are fine; their values are not.

## 4) Reply in chat

1. A summary of **at most 10 lines**: what got done · what is still open · how many questions are waiting on the user · the path of the handoff file · the predecessor deleted (or "new stream").
2. The **starter prompt** in a single ```` ```text ```` block, so it copies in one go:

```text
Continue from the <date> session (<topic>). First read the handoff `<path to handoff file>` (status per item, env/ops, open questions, proposed order)<, plus any project docs it points to>.

Before starting any work (no subagents yet):
1. In <repos with open work>: `git status --short`, `git log --oneline <base>..HEAD` and `HEAD..<base>` — confirm the open items (<IDs>) are still there and not mixed with other sessions' work. If local is behind the remote, sync with a merge — never stash or reset.
2. Check the services this work needs: <ports / servers / emulators>.
3. Give me a short table: ready for PR · waiting for in-app testing · blocked on my answer.

Open questions: <one line each, or "ask me one at a time when we reach that item">

Order: <step 1> → <step 2> → …

<Standing rules I gave this session, e.g. budget, "merge after in-app test", max parallel agents>
```

The prompt must stand on its own (the next session can't see this conversation) and stay short enough to paste in one go. Details belong in the handoff file. Don't repeat them in the prompt.
