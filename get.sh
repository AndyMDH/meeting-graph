#!/usr/bin/env bash
# One-liner installer:
#   curl -fsSL https://raw.githubusercontent.com/AndyMDH/cortex/main/get.sh | bash
#
# Clones the repo to a scratch directory and runs the real installer with
# -y (full defaults, no interactive prompts - piping through `curl | bash`
# leaves no usable stdin for `read` to prompt against anyway). Re-run the
# clone step yourself and use `./install.sh` directly if you want to
# customize the install interactively.
set -euo pipefail

REPO_URL="https://github.com/AndyMDH/cortex.git"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Fetching Cortex..."
git clone --depth 1 --quiet "$REPO_URL" "$TMP_DIR/cortex"

cd "$TMP_DIR/cortex"
# Not `exec` here on purpose: exec replaces this shell's process image, which
# means the EXIT trap above (the /tmp cleanup) would never fire and every
# one-liner install would leak a full repo clone into /tmp permanently.
./install.sh -y "$@"
