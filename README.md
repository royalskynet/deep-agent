# deep-agent

Standalone repo for the `deep` agent — the default subagent that runs a task
end-to-end, headless, outside the sandbox, via deepclaude.

`deep` means: hand the raw task text to the deepclaude-backed Claude Code loop and
let it run to completion with no supervision. Three entry points:

- **Agent**: `subagent_type: deep` in a task / subagent dispatch.
- **`/deep`**: slash command that forwards the task through the `deep` shell.
- **Bash direct**: `deep-run <task.md> [cwd]`.

Dependencies: [royalskynet/deepclaude](https://github.com/royalskynet/deepclaude),
and `GH_TOKEN` in `~/.creds/kv` for `gh` access.

---

## Headless autonomous runs (deep-run)

Claude Code normally needs an interactive terminal or a remote-control session. For
long unattended coding jobs (migration, plumbing, doc generation), `deep-run` drives
the deepclaude-backed Claude Code loop headlessly: no TTY, no pausing, no "ask me
first" — it runs a single task end-to-end and prints a report.

**How to call it**:

```
deep-run <task.md> [cwd]
```

Behind the scenes it runs `claude -p` outside the sandbox with these flags:

```
--system-prompt-file config/deep-system.md
--tools Bash,Read,Edit,Write,Glob,Grep
--disable-slash-commands
--strict-mcp-config
--permission-mode bypassPermissions
--max-turns 150
```

No `--bare` on purpose: bare mode skips the `PreToolUse` hook, which would disarm the
`creds-egress-guard` that keeps credential values out of transcripts.

**The contract (`config/deep-system.md`)** — injected into the model as its system
prompt:

1. No supervision: never ask, never wait for confirmation.
2. Method in order: check past fixes → `gh search` repos/code/issues for a wheel
   (≤3 queries per problem) → smallest change → rerunnable verification → report in
   Traditional Chinese (what changed `path:line` / wheel URL or keywords / raw verify
   output / NOT DONE).
3. Irreversible or publish actions → stop and report.

**Task file format** — three sections, no step-by-step:

```
# 任務        (what to do)
# 驗收        (rerunnable acceptance command + expected output)
# 不動        (things never to touch)
```

Methodology lives in the system prompt, not the task file.

**Verification** — every run must end with a rerunnable command you can paste. See
`wrappers.log` for the call + `transcript` for the full trace.

**Known limits:**
- Must be called via `deep-run` by its bare name — an absolute path won't match the
  sandbox's excluded-commands allowlist and silently drops back into the sandbox
  (node DNS dies instantly, faking a 502). `deep-run` detects the sandbox proxy env
  and exits 3.
- `≤3` search queries per problem keeps hiring fast but can feel slow on hard tasks
  (a smoke test took 40 `gh` calls, 6.5 min, 29 turns to pick one of 5 candidates).
- Interactive or vision-dependent tasks won't survive headless runs.

### 中文說明

Claude Code 平常需要互動終端或遠端控制連線。要跑長時間無人看守的程式任務（搬檔、
接線、生文件）時，`deep-run` 以無頭方式驅動 deepclaude 背後的 Claude Code 迴圈：
不開 TTY、不停頓、不「先問再動」——單一任務一路做到完，輸出報告。

**呼叫方式**：

```
deep-run <task.md> [cwd]
```

內部在沙箱外執行 `claude -p`，旗標如下：

```
--system-prompt-file config/deep-system.md
--tools Bash,Read,Edit,Write,Glob,Grep
--disable-slash-commands
--strict-mcp-config
--permission-mode bypassPermissions
--max-turns 150
```

刻意不用 `--bare`：bare 模式會跳過 `PreToolUse` hook，等於廢掉 `creds-egress-guard`
（保護憑證值不外洩 transcript）。

**契約（`config/deep-system.md`）**——注入模型當 system prompt：

1. 無人看守：不准問、不准等確認。
2. 方法依序：查舊帳 → `gh search` repos/code/issues 找輪子（每題 ≤3 query）→ 最小
   改動 → 可重跑驗證 → 繁中回報（改了啥 `path:line`／輪子 URL 或查過的關鍵字／驗證
   原始輸出／NOT DONE）。
3. 不可逆或對外發布 → 停下回報。

**任務檔格式**——三段，不寫步驟：

```
# 任務        （要做什麼）
# 驗收        （可重跑的驗收指令＋預期輸出）
# 不動        （絕不碰的東西）
```

方法論在 system prompt，不在任務檔。

**驗證**——每次 run 結尾必須有可重跑的指令。呼叫細節看 `wrappers.log`，完整軌跡
看 `transcript`。

**已知限制：**
- 必須用 `deep-run` 的 bare 名稱呼叫——絕對路徑不符合沙箱 excluded-commands 白名單，
  會無聲掉回沙箱（node DNS 秒死、偽裝成 502）。`deep-run` 偵測到沙箱 proxy env 即
  exit 3。
- 每題 ≤3 query 維持招聘速度，但硬任務會偏慢（煙測一次比 5 個候選用了 40 次 gh、
  6.5 分鐘、29 turns）。
- 需要互動或 vision 的任務活不過無頭執行。

## Install

```
cd deep-agent
./install.sh
```

Symlinks the repo into place (deepclaude's agent / skill / command, plus
`~/.local/bin/deep-run`). Requires deepclaude
([royalskynet/deepclaude](https://github.com/royalskynet/deepclaude)) and
`GH_TOKEN` in `~/.creds/kv`. Rerunnable; must be sourced from the current repo
checkout.