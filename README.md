# Cortex

Turn everything you dictate or paste — meeting transcripts, ideas, stray
thoughts — into a linked, tagged Obsidian knowledge graph. A daily pipeline
does the organizing so you don't have to.

I'm a consultant with back-to-back calls and no talent for note-taking.
Cortex is the fix: capture everything, let a daily pipeline remember it.
Nothing but the captured text touches the network, and only via the
Anthropic API through Claude Code.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/AndyMDH/cortex/main/get.sh | bash
```

This scaffolds a vault at `~/Obsidian/Cortex` with demo transcripts already
in the inbox. Run the pipeline once to see it work:

```bash
~/Obsidian/Cortex/90-System/run.sh
```

Then check `10-Meetings/` for the enriched notes — if they're there, you're
set. Want to customize the install (vault location, tags, git backup)?
Clone the repo and run `./install.sh` instead of the one-liner.

Something broken? Run `90-System/doctor.sh` inside your vault.

## Requirements

- macOS, [Claude Code](https://docs.claude.com/claude-code) (authenticated),
  [Obsidian](https://obsidian.md), and a dictation tool (built against
  [Handy](https://handy.computer/))
- `git`, and optionally [`gh`](https://cli.github.com/) if you want a backup repo set up for you

## How it works

```
dictate/paste -> 00-Inbox/ -> meeting-enricher -> 10-Meetings/ -> wiki-builder -> 20-Wikis/
```

Two Claude Code skills do the work, run daily via `launchd`:

- **meeting-enricher** tags, summarizes, and links each new note, pulling
  tags only from `30-Tags/` (no tag sprawl) and preserving your raw text
  underneath.
- **wiki-builder** synthesizes a wiki page once a topic has enough notes
  behind it (default: 4), turning scattered notes into a readable hub
  instead of a hairball of cross-links.

Everything is plain markdown + YAML frontmatter — no database, fully
inspectable and editable by hand.

## Customizing

- `.claude/skills/*/SKILL.md` — the pipeline's actual behavior. It's prose,
  edit it like a prompt.
- `30-Tags/` — your tag vocabulary.
- `90-System/run.sh` — the daily schedule and orchestration.

Pull future updates into an existing vault with `./update.sh <vault-path>`
(from a fresh clone of this repo).

## License

MIT — see [LICENSE](LICENSE). Issues and PRs welcome.
