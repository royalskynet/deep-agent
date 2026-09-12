---
name: deep
description: 派工 deep — 像派 sonnet：主 session 出完計畫說「派 deep」，Bash 直呼 deep-run <計畫.md> → deepclaude（CheaperInference deepseek-v4-flash-0731，沙箱外跑、可寫任何路徑）。沒計畫就一句任務＋一條驗收。deep 自主：查 fixindex、gh 找輪子、做完驗證回報。使用者說「派工 deep」「派 deep」「deep 去查」「/deep」即用。
---
# deep = 自主執行者，主 session = 出題＋驗收

**分工（2026-09-12 v2）**：主 session 只出題（計畫或一句任務）＋驗收，不寫執行指令。方法論（先查舊帳 → gh 找輪子 → 最小改動 → 可重跑驗證）在 `~/.deepclaude/config/deep-system.md`，deep 自己跑。deep 經 `deep-run` 在**沙箱外**跑，能寫 `~/.claude/**`、`.git/config` 等沙箱擋的路徑。

## 任務檔
- **常態：主 session 剛出過計畫 md** → 任務檔＝那份計畫（絕對路徑），**不重寫、不摘要、不拆步驟**。計畫缺驗收就 append 一行「驗收：<一條指令＋期望>」。
- **沒計畫** → scratchpad `deep/<slug>.md` 三段：**任務**（原文＋deep 不可能自己知道的前情：絕對路徑、限制、期望格式）／**驗收**（一條可重跑指令＋期望；想不出寫「自訂驗收並貼輸出」）／**不動**（可省）。
- 含憑證路徑字串（如 `.creds/*/.env`）用 Write tool 寫，Bash heredoc 會被 creds-egress-guard 攔。

## 派工（兩條路，預設 Agent）
- **預設：Agent tool `subagent_type: deep`**（`~/.claude/agents/deep.md`，haiku 殼、只有 Bash，像 codex-rescue 一樣純轉發）。prompt 就是任務原文（或「執行 <計畫.md 絕對路徑>」＋驗收一行），殼層原封寫任務檔→裸名 deep-run→回傳 stdout。多一跳 haiku 成本換一句話派工。
- **Bash 直呼**：主 session 要 `run_in_background` 自己控進度、或要指定 cwd／串多個任務時用。
- `deep-run <task.md> <cwd>`，**裸名**（絕對路徑不匹配 excludedCommands 會掉回沙箱，deep-run 會 exit 3 提示），單一原子指令（禁 pipe／&&／$()／heredoc 同 call；timeout 600000）。預估 >2 分鐘 → `run_in_background: true`。
- deep 工具：Bash／Read／Edit／Write／Glob／Grep；`gh` 走 deep-run 注入的 `GH_TOKEN`（kv 鏡像），不靠 keyring。任務不得要求 Agent／WebFetch／WebSearch／MCP。
- 每轉前綴約 5.5k tokens；長任務照派，成本在 DeepSeek 端。

## 驗收
- 主 session 重跑驗收指令；宣告 ≠ 生效。
- `tail -2 ~/Library/Logs/openclaw/wrappers.log` 應有 `deep-run start`／`end rc=`。
- deep 回報偶爾吞段 → 以 transcript 為準：`ls -t ~/.deepclaude/config/projects/<cwd-slug>/*.jsonl | head -1`，`jq` 取 `tool_result`。

## 不做
- 需要 Anthropic 推理深度的決策（設計權衡、含糊需求解讀）留主 session。
- deep-run 是沙箱逃生門：任務內禁 `set -x`、禁印憑證值（deepclaude 端掛同一支 `creds-egress-guard.js`；**deep-run 不得加 `--bare`**，會跳過 hooks）。
