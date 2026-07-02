#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/vault-template"

DEFAULT_VAULT_PATH="$HOME/Obsidian/Cortex"
DEFAULT_TAGS="project, internal, external"
DEFAULT_RUN_TIME="18:30"
DEFAULT_ALIAS="cortex-run"

NONINTERACTIVE="N"
CLI_VAULT_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes) NONINTERACTIVE="Y"; shift ;;
    -p|--path)
      if [ -z "${2:-}" ]; then
        echo "Error: --path requires a value" >&2
        exit 1
      fi
      CLI_VAULT_PATH="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ./install.sh [-y|--yes] [-p|--path <dir>]"
      echo
      echo "  -y, --yes     Non-interactive: scaffold with defaults, skip git and"
      echo "                launchd setup. Re-run without this flag any time to"
      echo "                customize, or edit the vault directly afterwards."
      echo "  -p, --path    Vault location. Works with or without -y; in"
      echo "                interactive mode it just becomes the prompt's default."
      exit 0
      ;;
    *)
      echo "Unknown argument: $1 (see --help)" >&2
      exit 1
      ;;
  esac
done

echo "Cortex installer"
echo "================="
echo

# --- Dependency checks -------------------------------------------------

if ! command -v claude >/dev/null 2>&1; then
  echo "Warning: 'claude' (Claude Code CLI) not found on PATH."
  echo "The pipeline won't run until it's installed: https://docs.claude.com/claude-code"
  echo
fi
CLAUDE_DIR="$(command -v claude >/dev/null 2>&1 && dirname "$(command -v claude)" || echo "/usr/local/bin")"

if ! command -v git >/dev/null 2>&1; then
  echo "Warning: 'git' not found on PATH. Git sync setup will be skipped."
fi

# --- Prompts (or defaults) ------------------------------------------------

if [ "$NONINTERACTIVE" = "Y" ]; then
  VAULT_PATH="${CLI_VAULT_PATH:-$DEFAULT_VAULT_PATH}"
  VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
  STARTER_TAGS="$DEFAULT_TAGS"
  RUN_TIME="$DEFAULT_RUN_TIME"
  ALIAS_NAME="$DEFAULT_ALIAS"
  COPY_DEMOS="Y"
  SETUP_GIT="N"
  CREATE_GH_REPO="N"
  LOAD_LAUNCHD="N"

  echo "Non-interactive install - using defaults:"
  echo "  Vault path:      $VAULT_PATH"
  echo "  Starter tags:    $STARTER_TAGS"
  echo "  Daily run time:  $RUN_TIME"
  echo "  Alias:           $ALIAS_NAME"
  echo "  Demo transcripts: yes   Git sync: no   Daily schedule: no"
  echo "  (re-run ./install.sh without -y any time to customize instead)"
  echo
else
  PROMPT_DEFAULT_VAULT_PATH="${CLI_VAULT_PATH:-$DEFAULT_VAULT_PATH}"
  read -rp "Where should the vault live? [$PROMPT_DEFAULT_VAULT_PATH]: " VAULT_PATH
  VAULT_PATH="${VAULT_PATH:-$PROMPT_DEFAULT_VAULT_PATH}"
  VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

  read -rp "Starter tags, comma-separated [$DEFAULT_TAGS]: " STARTER_TAGS
  STARTER_TAGS="${STARTER_TAGS:-$DEFAULT_TAGS}"

  read -rp "Daily run time, 24h HH:MM [$DEFAULT_RUN_TIME]: " RUN_TIME
  RUN_TIME="${RUN_TIME:-$DEFAULT_RUN_TIME}"

  read -rp "Alias name for manual runs [$DEFAULT_ALIAS]: " ALIAS_NAME
  ALIAS_NAME="${ALIAS_NAME:-$DEFAULT_ALIAS}"

  read -rp "Copy demo transcripts into 00-Inbox so you can try it immediately? [Y/n]: " COPY_DEMOS
  COPY_DEMOS="${COPY_DEMOS:-Y}"

  SETUP_GIT="N"
  if command -v git >/dev/null 2>&1; then
    read -rp "Set up a dedicated git repo for this vault now? [y/N]: " SETUP_GIT
    SETUP_GIT="${SETUP_GIT:-N}"
  fi

  CREATE_GH_REPO="N"
  if [[ "$SETUP_GIT" =~ ^[Yy] ]] && command -v gh >/dev/null 2>&1; then
    read -rp "Create a private GitHub repo and push to it too? [y/N]: " CREATE_GH_REPO
    CREATE_GH_REPO="${CREATE_GH_REPO:-N}"
    if [[ "$CREATE_GH_REPO" =~ ^[Yy] ]]; then
      read -rp "GitHub repo name [$(basename "$VAULT_PATH")]: " GH_REPO_NAME
      GH_REPO_NAME="${GH_REPO_NAME:-$(basename "$VAULT_PATH")}"
    fi
  fi

  LOAD_LAUNCHD="N"
  read -rp "Load the daily launchd job now? [y/N]: " LOAD_LAUNCHD
  LOAD_LAUNCHD="${LOAD_LAUNCHD:-N}"
fi

VAULT_NAME="$(basename "$VAULT_PATH")"
RUN_HOUR="${RUN_TIME%%:*}"
RUN_MINUTE="${RUN_TIME##*:}"
RUN_HOUR=$((10#$RUN_HOUR))
RUN_MINUTE=$((10#$RUN_MINUTE))

if [ -e "$VAULT_PATH" ] && [ -n "$(ls -A "$VAULT_PATH" 2>/dev/null)" ]; then
  echo "Error: $VAULT_PATH already exists and is not empty. Choose a different path."
  exit 1
fi

# --- Scaffold --------------------------------------------------------------

echo
echo "Scaffolding vault at $VAULT_PATH ..."
mkdir -p "$VAULT_PATH"
cp -R "$TEMPLATE_DIR/." "$VAULT_PATH/"

INSTALL_DATE="$(date +%Y-%m-%d)"

# Substitute placeholders (use | as sed delimiter since paths contain /)
substitute() {
  local file="$1"
  sed -i '' \
    -e "s|{{VAULT_PATH}}|$VAULT_PATH|g" \
    -e "s|{{VAULT_NAME}}|$VAULT_NAME|g" \
    -e "s|{{ALIAS_NAME}}|$ALIAS_NAME|g" \
    -e "s|{{CLAUDE_DIR}}|$CLAUDE_DIR|g" \
    -e "s|{{RUN_HOUR}}|$RUN_HOUR|g" \
    -e "s|{{RUN_MINUTE}}|$RUN_MINUTE|g" \
    -e "s|{{INSTALL_DATE}}|$INSTALL_DATE|g" \
    "$file"
}

mv "$VAULT_PATH/90-System/run.sh.template" "$VAULT_PATH/90-System/run.sh"
substitute "$VAULT_PATH/90-System/run.sh"
chmod +x "$VAULT_PATH/90-System/run.sh"

mv "$VAULT_PATH/90-System/quick-capture.sh.template" "$VAULT_PATH/90-System/quick-capture.sh"
substitute "$VAULT_PATH/90-System/quick-capture.sh"
chmod +x "$VAULT_PATH/90-System/quick-capture.sh"

mv "$VAULT_PATH/90-System/com.cortex.pipeline.plist.template" \
   "$VAULT_PATH/90-System/com.cortex.pipeline.plist"
substitute "$VAULT_PATH/90-System/com.cortex.pipeline.plist"

mv "$VAULT_PATH/README.md.template" "$VAULT_PATH/README.md"
substitute "$VAULT_PATH/README.md"

substitute "$VAULT_PATH/30-Tags/fragment.md"

chmod +x "$VAULT_PATH/90-System/doctor.sh"

touch "$VAULT_PATH/90-System/pipeline.log"

# Record install-time settings so `update.sh` can re-substitute templates
# later without re-asking every question.
cat > "$VAULT_PATH/90-System/.cortex-config" <<EOF
VAULT_PATH=$VAULT_PATH
VAULT_NAME=$VAULT_NAME
ALIAS_NAME=$ALIAS_NAME
CLAUDE_DIR=$CLAUDE_DIR
RUN_HOUR=$RUN_HOUR
RUN_MINUTE=$RUN_MINUTE
EOF

# Seed starter tags
IFS=',' read -ra TAGS <<< "$STARTER_TAGS"
for raw_tag in "${TAGS[@]}"; do
  tag="$(echo "$raw_tag" | xargs | tr '[:upper:] ' '[:lower:]-')"
  [ -z "$tag" ] && continue
  cat > "$VAULT_PATH/30-Tags/$tag.md" <<EOF
---
type: tag
created: $INSTALL_DATE
---
# $tag

One-line definition of what belongs under this tag.

## Notes with this tag
(Obsidian backlinks panel shows these automatically - leave this section empty)
EOF
done

# Obsidian: new notes go to 00-Inbox by default
mkdir -p "$VAULT_PATH/.obsidian"
cat > "$VAULT_PATH/.obsidian/app.json" <<'EOF'
{
  "newFileLocation": "folder",
  "newFileFolderPath": "00-Inbox",
  "attachmentFolderPath": "90-System/attachments"
}
EOF

if [[ "$COPY_DEMOS" =~ ^[Yy] ]]; then
  cp "$SCRIPT_DIR/demo-transcripts/"*.md "$VAULT_PATH/00-Inbox/" 2>/dev/null || true
fi

echo "Vault scaffolded."

# --- Git setup ---------------------------------------------------------

if [[ "$SETUP_GIT" =~ ^[Yy] ]]; then
  (
    cd "$VAULT_PATH"
    git init -q
    cat > .gitignore <<'EOF'
.DS_Store
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/cache
.obsidian/plugins/
.trash/
EOF
    git add -A
    git commit -q -m "Initial commit: Cortex vault"
    echo "Initialized a dedicated git repo at $VAULT_PATH/.git"
    TOPLEVEL="$(git rev-parse --show-toplevel)"
    if [ "$TOPLEVEL" != "$VAULT_PATH" ]; then
      echo "Warning: git top-level resolved to $TOPLEVEL, not $VAULT_PATH."
      echo "Something is off - check for a parent .git directory."
    fi
  )

  if [[ "$CREATE_GH_REPO" =~ ^[Yy] ]]; then
    (
      cd "$VAULT_PATH"
      gh repo create "$GH_REPO_NAME" --private --source=. --remote=origin
      git branch -M main
      git push -u origin main
    )
    echo "Pushed to a private GitHub repo: $GH_REPO_NAME"
  fi
fi

# --- launchd -------------------------------------------------------------

PLIST_DEST="$HOME/Library/LaunchAgents/com.cortex.pipeline.plist"
if [[ "$LOAD_LAUNCHD" =~ ^[Yy] ]]; then
  cp "$VAULT_PATH/90-System/com.cortex.pipeline.plist" "$PLIST_DEST"
  launchctl load "$PLIST_DEST"
  echo "Loaded launchd job: runs daily at $RUN_TIME."
else
  echo "Skipped launchd. To enable the daily run later:"
  echo "  cp \"$VAULT_PATH/90-System/com.cortex.pipeline.plist\" \"$PLIST_DEST\""
  echo "  launchctl load \"$PLIST_DEST\""
fi

# --- Summary ---------------------------------------------------------------

echo
echo "Done. Vault created at: $VAULT_PATH"
echo
echo "Run the doctor script any time to check your setup:"
echo "  $VAULT_PATH/90-System/doctor.sh"
echo
echo "Next steps (manual, need the Obsidian/dictation-tool GUIs):"
echo "  1. open -a Obsidian \"$VAULT_PATH\""
echo "  2. In your dictation tool's settings: grant Microphone, Accessibility,"
echo "     and Input Monitoring permission (System Settings > Privacy & Security)."
echo "     Enable toggle/hands-free recording mode if available."
echo "  3. In Obsidian: Graph view > Groups, add color groups for path:30-Tags,"
echo "     path:20-Wikis, path:10-Meetings (see README.md for details)."
echo "  4. Add real starter tags to 30-Tags/ that match your actual work before"
echo "     your first real meeting."
echo
echo "Manual pipeline run: $VAULT_PATH/90-System/run.sh"
echo "Add this alias to your shell profile:"
echo "  alias $ALIAS_NAME=\"$VAULT_PATH/90-System/run.sh\""
echo
echo "Optional: $VAULT_PATH/90-System/quick-capture.sh creates+opens a new"
echo "00-Inbox note without switching to Obsidian first. Bind it to a global"
echo "hotkey via Shortcuts.app > New Shortcut > Run Shell Script (see vault"
echo "README.md, 'Quick capture' section) if you want that."
echo
echo "To pull future improvements to the skills/pipeline into this vault later,"
echo "clone the repo fresh (don't rely on wherever this install ran from - if"
echo "you used the one-liner, that clone was in a temp dir) and run update.sh:"
echo "  git clone https://github.com/AndyMDH/cortex.git && cd cortex"
echo "  ./update.sh \"$VAULT_PATH\""
