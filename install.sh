#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"

mkdir -p ~/.local/bin ~/.claude/agents ~/.claude/skills ~/.claude/commands

ln -sfn "$REPO/bin/deep-run" ~/.local/bin/deep-run
ln -sfn "$REPO/claude/agents/deep.md" ~/.claude/agents/deep.md

# ~/.claude/skills/deep: if it is a real directory, back it up before linking
if [ -d ~/.claude/skills/deep ] && [ ! -L ~/.claude/skills/deep ]; then
  mv ~/.claude/skills/deep ~/.claude/skills/deep.bak-$(date +%Y%m%d)
fi
ln -sfn "$REPO/claude/skills/deep" ~/.claude/skills/deep

ln -sfn "$REPO/claude/commands/deep.md" ~/.claude/commands/deep.md

echo "Installed symlinks:"
for t in ~/.local/bin/deep-run ~/.claude/agents/deep.md ~/.claude/skills/deep ~/.claude/commands/deep.md; do
  ls -l "$t"
done