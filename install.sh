#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"

mkdir -p ~/.local/bin ~/.claude/skills ~/.claude/commands

ln -sfn "$REPO/bin/deep-run" ~/.local/bin/deep-run
ln -sfn "$REPO/bin/deep-lint" ~/.local/bin/deep-lint

# ~/.claude/skills/deep: if it is a real directory, back it up inside the repo before linking
if [ -d ~/.claude/skills/deep ] && [ ! -L ~/.claude/skills/deep ]; then
  mkdir -p "$REPO/.bak"
  mv ~/.claude/skills/deep "$REPO/.bak/deep-$(date +%Y%m%d)"
fi
ln -sfn "$REPO/claude/skills/deep" ~/.claude/skills/deep

ln -sfn "$REPO/claude/commands/deep.md" ~/.claude/commands/deep.md

mkdir -p ~/.deepclaude/config/hooks
ln -sfn "$REPO/deep-agent/hooks/deep-stop-gate.sh" ~/.deepclaude/config/hooks/deep-stop-gate.sh

echo "Installed symlinks:"
for t in ~/.local/bin/deep-run ~/.local/bin/deep-lint ~/.claude/skills/deep ~/.claude/commands/deep.md ~/.deepclaude/config/hooks/deep-stop-gate.sh; do
  ls -l "$t"
done