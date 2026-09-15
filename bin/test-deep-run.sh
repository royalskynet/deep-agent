#!/usr/bin/env bash
# Self-check for how deep-run composes the Claude Code invocation. No network: a stub
# `deepclaude` earlier on PATH records argv and environment instead of running one.
# Run: deep-agent/bin/test-deep-run.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/deep-run-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
# deep-run prepends $HOME/.local/bin to PATH, so that is where the stub has to live
# for it to win — pointing PATH at a scratch dir is not enough.
mkdir -p "$tmp/home/.local/bin" "$tmp/work" "$tmp/home/.deepclaude/config" "$tmp/home/.creds/kv"
touch "$tmp/home/.deepclaude/config/deep-system.md"
echo 'task' > "$tmp/task.md"

cat > "$tmp/home/.local/bin/deepclaude" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$STUB_ARGV"
env | grep -E '^(CHEAPERINFERENCE_MODEL|DC_MAIN_HARNESS_FILE|DC_LOOP_GUARD)=' | sort > "$STUB_ENV"
STUB
chmod +x "$tmp/home/.local/bin/deepclaude"

HOME="$tmp/home" CREDS_DIR="$tmp/home/.creds" \
  STUB_ARGV="$tmp/argv" STUB_ENV="$tmp/env" WLOG="$tmp/w.log" HTTPS_PROXY="" \
  "$HERE/deep-run" "$tmp/task.md" "$tmp/work" >/dev/null 2>&1

argv=$(cat "$tmp/argv" 2>/dev/null) || { echo "FAIL: stub never ran"; exit 1; }
envs=$(cat "$tmp/env" 2>/dev/null)
fail=0
check() { if eval "$2"; then :; else echo "FAIL: $1"; fail=1; fi; }

# The working directory has to be stated: --system-prompt-file replaces Claude Code's
# default prompt, taking the environment block that names the cwd with it. Without
# this, deep searches the filesystem for its own task files.
check "--append-system-prompt names the cwd"      'grep -qF -- "$tmp/work" <<< "$argv" && grep -qx -- "--append-system-prompt" <<< "$argv"'
check "--system-prompt-file still passed"          'grep -qx -- "--system-prompt-file" <<< "$argv"'
# --bare skips hooks, which disarms the credential-egress guard. Measured, not assumed.
check "no --bare"                                  '! grep -qx -- "--bare" <<< "$argv"'
# deep has no Agent tool, which is why it needs the MAIN harness rather than the
# subagent one; if Agent ever appears here, that reasoning no longer holds.
check "no Agent tool"                              '! grep -q "Agent" <<< "$argv"'
check "--permission-mode bypassPermissions"        'grep -qx -- "bypassPermissions" <<< "$argv"'
check "--max-turns set"                            'grep -qx -- "--max-turns" <<< "$argv"'
check "pins the cheap model"                       'grep -q "^CHEAPERINFERENCE_MODEL=deepseek-v4-flash" <<< "$envs"'
check "points the proxy at the main harness"       'grep -q "^DC_MAIN_HARNESS_FILE=.*subagent-harness.md$" <<< "$envs"'
check "loop guard on by default"                   'grep -qx "DC_LOOP_GUARD=on" <<< "$envs"'

# An absolute path bypasses the sandbox allowlist entry ("deep-run *"), so deep-run
# must refuse rather than silently run inside the sandbox with DNS dead.
out=$(HOME="$tmp/home" WLOG="$tmp/w.log" HTTPS_PROXY="http://localhost:8080" \
      "$HERE/deep-run" "$tmp/task.md" "$tmp/work" 2>&1); rc=$?
check "refuses to run inside the sandbox"          '[ "$rc" = 3 ] && grep -q "INSIDE sandbox" <<< "$out"'

[ "$fail" = 0 ] && echo "OK: 10/10 deep-run invocation checks passed"
exit "$fail"
