# meeting-graph

Turn meeting transcripts into a growing Obsidian knowledge graph, fully local
except for the LLM calls that do the enrichment.

You dictate (or paste) a meeting transcript into an Obsidian note. A daily
pipeline reads it, writes a structured summary, tags it from a controlled
registry (no tag sprawl), links it to related meetings, and — once a topic
has enough meetings behind it — synthesizes a wiki page that becomes a hub
node in your graph. Nothing but the transcript text touches the network, and
only via the Anthropic API through Claude Code.

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
  Summary / Key points / Decisions / Action items while preserving the raw
  transcript verbatim, and links related notes.
- **`wiki-builder`** (a second skill): once a topic accumulates enough
  meeting notes (default: 4), synthesizes a single narrative wiki page in
  `20-Wikis/` that all of them link into — turning what would otherwise be a
  hairball of meeting-to-meeting links into a readable hub-and-spoke graph.
- **`run.sh` + launchd**: runs both skills daily, with an early exit (no API
  calls) if the inbox is empty, and optional git sync if you set one up.

Everything is plain markdown files with YAML frontmatter — no database, no
proprietary format, fully inspectable and editable by hand at any point.

## Requirements

- macOS (the scheduling piece uses `launchd`; the rest is plain bash and
  should work anywhere Claude Code runs, but this hasn't been tested outside
  macOS)
- [Claude Code](https://docs.claude.com/claude-code) installed and
  authenticated (`claude` on your `PATH`)
- [Obsidian](https://obsidian.md) (free)
- A dictation tool that types transcribed speech into the focused text field.
  This was built and tested against Handy, a local speech-to-text app — but
  anything with the same "types at cursor" behavior works the same way.
- `git` and (optionally) the [`gh` CLI](https://cli.github.com/) if you want
  the installer to set up a backup repo for you
- Optional: the [Templater](https://silentvoid13.github.io/Templater/)
  community plugin, if you want new `00-Inbox/` notes auto-stamped with a
  capture timestamp (see "Customizing" below). Not required for the pipeline
  itself.

## Quickstart

```bash
git clone https://github.com/AndyMDH/meeting-graph.git
cd meeting-graph
./install.sh
```

The installer asks a handful of questions (where the vault should live,
starter tags, daily run time, whether to set up git/GitHub, whether to load
the daily schedule now) and scaffolds a ready-to-use vault. It defaults to
copying in a few demo transcripts so you can see the whole pipeline run
end-to-end before you trust it with real meetings:

```bash
~/Obsidian/MeetingGraph/90-System/run.sh   # or wherever you pointed it
```

Check `10-Meetings/` afterwards for the enriched notes.

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
- **`90-System/templates/inbox-capture.md`** — an optional capture-timestamp
  template. Wire it up in Obsidian if you want it: install the Templater
  community plugin (Settings → Community plugins — requires turning off
  Restricted Mode), then in Templater's settings set "Templates folder
  location" to `90-System/templates`, enable "Folder templates", and add a
  rule mapping `00-Inbox` → `90-System/templates/inbox-capture.md`. This is
  UI-only setup the installer can't script, so it isn't automated — and
  entirely skippable, since `meeting-enricher` infers the date on its own
  regardless. Note `.gitignore` excludes `.obsidian/plugins/`: plugin code is
  Obsidian-managed, not vault content, so it shouldn't get vendored into your
  git history (and will re-download itself from Community Plugins if you ever
  reinstall).
- **`90-System/quick-capture.sh`** — creates and opens a new `00-Inbox` note
  without switching to Obsidian first. Bind it to a global hotkey via
  Shortcuts.app (see vault README) if you want one-keystroke capture from
  anywhere.

See the vault's own `README.md` (generated by the installer) for day-to-day
usage, the Obsidian graph-view setup, and the git-sync gotcha worth knowing
about before you turn it on.

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
