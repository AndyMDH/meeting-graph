#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/vault-template"

echo "meeting-graph installer"
echo "========================"
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

# --- Prompts -------------------------------------------------------------

read -rp "Where should the vault live? [$HOME/Obsidian/MeetingGraph]: " VAULT_PATH
VAULT_PATH="${VAULT_PATH:-$HOME/Obsidian/MeetingGraph}"
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
VAULT_NAME="$(basename "$VAULT_PATH")"

if [ -e "$VAULT_PATH" ] && [ -n "$(ls -A "$VAULT_PATH" 2>/dev/null)" ]; then
  echo "Error: $VAULT_PATH already exists and is not empty. Choose a different path."
  exit 1
fi

read -rp "Starter tags, comma-separated [project, internal, external]: " STARTER_TAGS
STARTER_TAGS="${STARTER_TAGS:-project, internal, external}"

read -rp "Daily run time, 24h HH:MM [18:30]: " RUN_TIME
RUN_TIME="${RUN_TIME:-18:30}"
RUN_HOUR="${RUN_TIME%%:*}"
RUN_MINUTE="${RUN_TIME##*:}"
RUN_HOUR=$((10#$RUN_HOUR))
RUN_MINUTE=$((10#$RUN_MINUTE))

read -rp "Alias name for manual runs [meeting-graph-run]: " ALIAS_NAME
ALIAS_NAME="${ALIAS_NAME:-meeting-graph-run}"

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
    read -rp "GitHub repo name [$VAULT_NAME]: " GH_REPO_NAME
    GH_REPO_NAME="${GH_REPO_NAME:-$VAULT_NAME}"
  fi
fi

LOAD_LAUNCHD="N"
read -rp "Load the daily launchd job now? [y/N]: " LOAD_LAUNCHD
LOAD_LAUNCHD="${LOAD_LAUNCHD:-N}"

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

mv "$VAULT_PATH/90-System/com.meeting-graph.pipeline.plist.template" \
   "$VAULT_PATH/90-System/com.meeting-graph.pipeline.plist"
substitute "$VAULT_PATH/90-System/com.meeting-graph.pipeline.plist"

mv "$VAULT_PATH/README.md.template" "$VAULT_PATH/README.md"
substitute "$VAULT_PATH/README.md"

substitute "$VAULT_PATH/30-Tags/fragment.md"

touch "$VAULT_PATH/90-System/pipeline.log"

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
    git commit -q -m "Initial commit: meeting-graph vault"
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

PLIST_DEST="$HOME/Library/LaunchAgents/com.meeting-graph.pipeline.plist"
if [[ "$LOAD_LAUNCHD" =~ ^[Yy] ]]; then
  cp "$VAULT_PATH/90-System/com.meeting-graph.pipeline.plist" "$PLIST_DEST"
  launchctl load "$PLIST_DEST"
  echo "Loaded launchd job: runs daily at $RUN_TIME."
else
  echo "Skipped launchd. To enable the daily run later:"
  echo "  cp \"$VAULT_PATH/90-System/com.meeting-graph.pipeline.plist\" \"$PLIST_DEST\""
  echo "  launchctl load \"$PLIST_DEST\""
fi

# --- Summary ---------------------------------------------------------------

echo
echo "Done. Vault created at: $VAULT_PATH"
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
