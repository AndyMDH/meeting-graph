# Cortex

A local knowledge graph, built automatically from everything you capture —
fully local except for the LLM calls that do the enrichment.

**New here?** Just want to *use* Cortex → jump to [Install](#install). Want
to *understand or modify* the code → jump to [Repo layout](#repo-layout).

## The problem this solves

I'm a consultant — back-to-back calls, constant context-switching — and a
genuinely terrible note-taker. Those two things don't mix: the details that
matter most are exactly the ones that evaporate by the next call.

Cortex is the fix: capture everything by talking or pasting it in, and let
a daily pipeline do the remembering. It reads whatever landed in your
inbox, writes a structured summary, tags it from a controlled vocabulary
(no tag sprawl), links it to related notes, and — once a topic has enough
behind it — synthesizes a wiki page that becomes a hub node in your graph.
Meeting transcripts are the main thing that flows through it, but the same
pipeline handles any dictated or pasted thought — an idea, a reflection, a
stray thing you don't want to lose. The result is plain markdown files with
YAML frontmatter, browsable and editable by hand, that Obsidian renders as
a graph instead of a folder of unread notes.

Nothing but the captured text touches the network, and only via the
Anthropic API through Claude Code.

## Install

**Option A — one command, sane defaults:**

```bash
curl -fsSL https://raw.githubusercontent.com/AndyMDH/cortex/main/get.sh | bash
```

This clones the repo, scaffolds a vault at `~/Obsidian/Cortex`, seeds it
with generic starter tags, and copies in demo transcripts so you can see the
pipeline run end-to-end immediately. It skips git backup and the daily
scheduler — safe, reversible choices you can turn on later (see below).

**Option B — clone it yourself** if you want to review the script first or
answer the setup questions interactively (custom vault location, starter
tags, daily run time, git backup, scheduler):

```bash
git clone https://github.com/AndyMDH/cortex.git
cd cortex
./install.sh
```

Either way, once it's done:

```bash
~/Obsidian/Cortex/90-System/run.sh   # or wherever you pointed it
```

Then check `10-Meetings/` — you should see the demo transcripts enriched,
tagged, and linked. If you see that, you're set up correctly and ready to
point it at real meetings.

Something not working? Run `~/Obsidian/Cortex/90-System/doctor.sh` — it
checks dependencies, vault structure, and scheduler status in one shot.

Day-to-day usage (dictation setup, quick capture, graph coloring) is
documented in the vault's own generated `README.md` — read that one next.

## Requirements

- **macOS** (scheduling uses `launchd`; the rest is plain bash and should
  work anywhere Claude Code runs, but this hasn't been tested off macOS)
- **[Claude Code](https://docs.claude.com/claude-code)**, installed and
  authenticated (`claude` on your `PATH`) — this is what does the actual
  enrichment work
- **[Obsidian](https://obsidian.md)** (free) — this is where you'll read
  and browse the graph
- **A dictation tool** that types transcribed speech into the focused text
  field (built and tested against [Handy](https://handy.computer/); anything
  with the same "types at cursor" behavior works)
- **`git`**, and optionally the [`gh` CLI](https://cli.github.com/), if you
  want git backup set up for you (Option B only — see "Customizing" below)

## Repo layout

Start here if you want to understand what's actually on disk before you
change anything. Skip it if you just want to use Cortex day to day.

**This repo is a one-time installer, not the thing you use daily.** You
clone it, run it once (or via the one-liner), and it scaffolds a live
Obsidian vault somewhere else on disk. From that point on you work *in the
vault* — this repo only matters again if you're improving Cortex itself for
everyone (edit here, ship the change out with `update.sh`).

```
cortex/                              <- this repo, cloned once
  install.sh                         interactive scaffolder (the installer)
  get.sh                             non-interactive one-liner wrapper around install.sh
  update.sh                          re-syncs an existing vault's system files with this repo
  demo-transcripts/                  sample transcripts copied into 00-Inbox/ on first install

  vault-template/                    THE PRODUCT - copied wholesale to become your vault
    .claude/skills/
      meeting-enricher/SKILL.md      prompt: raw transcript -> structured, tagged, linked note
      wiki-builder/SKILL.md          prompt: cluster of notes -> synthesized wiki hub page
    90-System/
      run.sh.template                -> run.sh: the daily orchestration script
      doctor.sh                      preflight/health check, copied as-is (no substitution)
      quick-capture.sh.template      -> quick-capture.sh: hotkey-friendly note creation
      com.cortex.pipeline.plist.template   -> the launchd daily-schedule definition
      templates/                     Obsidian note templates (tag / wiki / meeting / inbox)
    00-Inbox/ 10-Meetings/ 20-Wikis/ 30-Tags/   empty scaffolds for the pipeline stages
    README.md.template               -> becomes the vault's own day-to-day README
```

Three layers, in the order they actually run:

1. **`install.sh` (this repo, runs once)** — asks a handful of questions (or
   takes `-y` for defaults), copies `vault-template/` to your chosen path,
   and substitutes placeholders like `{{VAULT_PATH}}` into the copy. It's a
   stamping machine, not a long-running process — it never runs again after
   install unless you're re-installing or updating.
2. **The vault (`vault-template/`, once instantiated)** — plain markdown +
   YAML frontmatter, no database. This is what you read, dictate into, and
   browse in Obsidian every day. `.claude/skills/` holds the two prompts
   that do all the actual thinking; everything else under it is data or
   orchestration around them.
3. **`run.sh` + launchd (inside the vault, runs daily)** — the only thing
   that executes on a schedule after install. It shells out to `claude -p`
   twice (enrich, then build wikis), syncs to git if you set that up, and
   fires a macOS notification summarizing what happened — including a
   distinct failure notification if either `claude` call errors, so a
   broken run is never silent.

**If you're contributing:** edit files under `vault-template/` in this
repo, never inside an already-scaffolded vault — changes made directly in a
vault are local to that one person and never reach anyone else. Push
changes out to existing vaults with `update.sh` (see "Pulling in updates"
below).

## How it works

```
dictate/paste  ->  00-Inbox/  ->  meeting-enricher  ->  10-Meetings/
                                                              |
                                                        wiki-builder
                                                              v
                                                        20-Wikis/ (hub pages)
```

- **`meeting-enricher`** (a Claude Code skill): adds frontmatter, infers a
  title/date/project, tags the note from a controlled registry in `30-Tags/`
  (creating a new tag is exceptional and logged), restructures the body into
  Summary / Key points / Decisions / Action items, and links related notes —
  all while preserving the raw source verbatim. Meeting transcripts get the
  full treatment; a standalone idea or reflection gets a lighter summary
  instead of a Decisions/Action items section it doesn't have.
- **`wiki-builder`** (a second skill): once a topic accumulates enough
  meeting notes (default: 4), synthesizes a single narrative wiki page in
  `20-Wikis/` that all of them link into — turning what would otherwise be a
  hairball of meeting-to-meeting links into a readable hub-and-spoke graph.
- **`run.sh` + launchd**: runs both skills daily, with an early exit (no API
  calls) if the inbox is empty, and optional git sync if you set one up. A
  failed run logs the error and notifies you distinctly from an empty-inbox
  run — it never fails silently.

## Customizing

Everything that matters is plain text you're meant to edit:

- **`30-Tags/`** — your tag registry. Add/rename/remove tag notes freely;
  `meeting-enricher` will only ever use what's actually there. Seed this with
  tags that match your actual domain before relying on it for real meetings —
  the installer's defaults (`project`, `internal`, `external`) are
  deliberately generic starting points, not a real taxonomy.
- **`.claude/skills/meeting-enricher/SKILL.md`** and
  **`.claude/skills/wiki-builder/SKILL.md`** — the actual behavior. The wiki
  threshold (default: 4 meeting notes before a wiki gets created), the tag
  creation bar, the max related-notes count — all just prose in these files.
  Edit them like you'd edit a prompt, because that's what they are.
- **`90-System/run.sh`** — the schedule and orchestration. The launchd plist
  controls *when* it runs; this controls *what* runs.
- **`90-System/doctor.sh`** — preflight/health check, safe to re-run any time.
- **`90-System/quick-capture.sh`** — creates and opens a new `00-Inbox` note
  without switching to Obsidian first. Bind it to a global hotkey via
  Shortcuts.app (see vault README) if you want one-keystroke capture from
  anywhere.

See the vault's own `README.md` (generated by the installer) for day-to-day
usage, the Obsidian graph-view setup, and the git-sync gotcha worth knowing
about before you turn it on.

### Pulling in updates

If you installed with the one-liner and later want to pick up improvements
to the pipeline or skills, clone the repo and run `update.sh` against your
existing vault — it re-copies the system files (`run.sh`, `quick-capture.sh`,
the launchd plist, `doctor.sh`, both skills) and never touches your notes:

```bash
git clone https://github.com/AndyMDH/cortex.git
cd cortex
./update.sh ~/Obsidian/Cortex   # or wherever your vault lives
```

## Why this shape

- **Tags as notes, not frontmatter-only strings**: every tag is a real file
  in `30-Tags/`, which makes it (a) a visible node in Obsidian's graph and
  (b) a registry the agent can read and be constrained by, rather than
  inventing tags freely. Tag sprawl is the thing that kills most
  auto-tagging setups; this is the guardrail against it.
- **Wikis as hub nodes**: without a synthesis step, a growing pile of linked
  meeting notes turns into a hairball. `wiki-builder` waits until a topic has
  real weight behind it, then writes an actual briefing document — not a
  list of links — that becomes the hub other notes point to.
- **Everything is a Claude Code skill, not a bespoke script**: the actual
  enrichment logic lives in `SKILL.md` prose, so improving it is an editing
  task, not a coding task.

## Contributing

Issues and PRs welcome — especially reports of what breaks on setups other
than the one this was built against (different Obsidian versions, other
dictation tools, non-macOS scheduling).

## License

MIT — see [LICENSE](LICENSE).
