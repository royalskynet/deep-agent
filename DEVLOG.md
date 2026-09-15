# 2026-09-15

`deep-run` now configures the proxy instead of inheriting whatever the interactive
launcher defaults to. It pins `deepseek-v4-flash-0731` (deep has no `Agent` tool, so
it never produces subagent traffic and a Pro-class main model costs ~10x for no
measured gain on this workload), prepends the ponytail harness to the main loop, and
turns on the loop guard. Paths are now `$HOME`/`$DC_HOME`-relative and the transcript
directory is derived from the cwd instead of being hardcoded.

`deep-run` 改成主動設定 proxy，而不是沿用互動式 launcher 的預設。釘 `deepseek-v4-flash-0731`
（deep 沒有 `Agent` 工具，不會產生 subagent 流量，主模型上 Pro 在這種用量下貴約 10 倍
而實測沒有對應收益）、把 ponytail harness 前置到主 loop、並開啟 loop guard。路徑改為
`$HOME`／`$DC_HOME` 相對，transcript 目錄由 cwd 推導，不再寫死。

Measured baseline that motivated the guard (32 real sessions): 87% of tool rounds
fired exactly one tool, 214k characters of narration, one 121-turn tail, repeated
commands 0.2%. Mechanism is verified by `proxy/test-loop-guard.mjs` (7/7) and by live
proxy logs; the behavioural effect is not yet established at n=2 per arm.

促成 guard 的實測基線（32 個真實 session）：87% 工具輪只發一個工具、敘述 21.4 萬字、
最長 121 輪、重複指令 0.2%。機制已由 `proxy/test-loop-guard.mjs`（7/7）與實跑 proxy log
驗證；行為上的改善在每組 n=2 的樣本下尚未成立。

# 2026-09-12

repo 建立，來源收攏自 agent-tools/.claude/.deepclaude。

Repo created; sources consolidated from agent-tools/.claude/.deepclaude.

agent-tools/sbin/deep-run 退役，唯一來源為本 repo。agent-tools/sbin/deep-run retired; this repo is the sole source.
repo 併入 royalskynet/deepclaude 頂層 `deep-agent/`（git subtree，歷史保留）；royalskynet/deep-agent 與 `~/dev/deep-agent` 刪除。symlink 改指 `~/.deepclaude/deep-agent/`。

Merged into royalskynet/deepclaude as top-level `deep-agent/` (git subtree, history kept); royalskynet/deep-agent and `~/dev/deep-agent` deleted. Symlinks now point at `~/.deepclaude/deep-agent/`.
