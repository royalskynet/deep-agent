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

**Corrected metric.** The first pass counted `tool_use` blocks and reported 87% of
rounds as "single-tool". That metric was wrong: a Bash call that chains commands with
`;`, `&&`, `||` or a newline is already a batch. Re-measured over 77 sessions /
1,780 rounds counting shell commands instead, only 35.8% of rounds do one thing
(4.27 commands per round) — the block count overstated the problem 2.5x. The guard
now counts shell commands (`shellUnits()`, quotes and heredoc bodies excluded), and
`DC_GUARD_SINGLES` moves 3 → 4: p90 of a genuine one-command run is 4, and the old
threshold would have nudged 62% of runs, most already batched.

`DC_GUARD_NARRATION` also had a real defect — `narration >= budget` fired on *every*
remaining round once crossed (240 nudges in the worst session). It now fires once per
doubling of the budget: same 28/77 session coverage, 6 nudges max.

Verified by `proxy/test-loop-guard.mjs` (13/13, was 7/7), by re-running the same
77-session corpus through the *shipped* `shellUnits()` (35.8% / 4.27 / p90 4 — the
documented numbers and the running code agree), and by four live `deep-run` arms:

| Arm | Config | Result |
|---|---|---|
| A | defaults | 7 rounds, **0 fires** — deep collapsed the task into shell loops, so nothing was degenerate to nudge |
| B | `SINGLES=2 ROUNDS=3` | 23 rounds, **13 fires** (G1 + G3), task still answered correctly |
| C | `NARRATION=400`, harness on | 5 rounds, **0 fires** — prose went into the file, not into assistant text |
| D | `NARRATION=400`, harness off | 12 requests, 5,141 chars of prose, **1 fire** at 2,088 — the doubling throttle held where `>=` would have fired every remaining round |

Two things the live arms settled that the unit tests could not. First, the guard's
`role:"system"` channel is one Claude Code already uses — dumped request bodies show
its own token-budget notices arriving the same way. Second, **while the harness is on,
deep writes 419–688 characters of prose per run**, so the default `DC_GUARD_NARRATION`
of 3000 effectively never fires; G2 is a backstop for a disabled or ignored harness,
not a routine control.

**A/B at n=8 per arm.** 16 `deep-run` audits of a 12-file fixture with 29 planted
defects, guard on/off, four concurrent, arms interleaved per batch so upstream drift
hits both equally:

| | guard on | guard off |
|---|---|---|
| rounds | 6.6 | 6.6 |
| narration | 2,403 | 2,575 |
| prompt tokens | 156,897 | 162,075 |
| produced the output file | 8/8 | 8/8 |
| defects found | 98% | 99% |

No effect, and the honest reason is in the replay: **across those 16 runs the guard
fired 3 times** (1 batching, 2 narration, 0 rounds). A treatment applied three times
cannot show an effect, so this A/B says nothing about whether the nudges work. Testing
that needs the degenerate tail — 8 of 78 corpus sessions — which at this base rate
means roughly 80 runs, not 16.

What the same 16 runs *do* measure is the metric fix, by replaying both versions of
the guard over their 118 tool rounds:

| | nudges | share of rounds | G1 | G2 |
|---|---|---|---|---|
| before (tool_use blocks, bare `>=`) | 29 | 25% | 18 | 11 |
| after (shell commands, doubling band) | 7 | 6% | 1 | 6 |

22 of 29 nudges were firing on healthy behaviour — mostly G1 scolding rounds that had
already batched their commands into one Bash call. Removing them cost nothing: both
arms produced output in 8/8 runs at 98-99% recall.

Arm B earlier showed deep correctly ignoring G1/G3 on genuinely serial work. That is
the right response, but it means compliance on work that really is batchable is still
untested.

**n=8 的 A/B。** 16 趟 `deep-run` 稽核同一份 12 檔、29 個植入缺陷的 fixture，guard 開／關，
四趟並行，每批兩開兩關交錯，讓上游波動平均落在兩臂：

| | guard 開 | guard 關 |
|---|---|---|
| 輪數 | 6.6 | 6.6 |
| 旁白字數 | 2,403 | 2,575 |
| prompt token | 156,897 | 162,075 |
| 有產出檔案 | 8/8 | 8/8 |
| 找到的缺陷 | 98% | 99% |

沒有差異，而誠實的原因在回放裡：**這 16 趟裡 guard 總共只觸發 3 次**（批次 1、旁白 2、
輪數 0）。施了三次的藥測不出療效，所以這個 A/B 對「nudge 有沒有用」沒有結論。要測那個
得取到退化長尾——78 個 session 裡的 8 個——照這個基礎比率大約要 80 趟，不是 16 趟。

同樣這 16 趟真正能測的是指標修正本身。把新舊兩版 guard 都回放過它們的 118 個工具輪：

| | nudge 次數 | 佔輪次 | G1 | G2 |
|---|---|---|---|---|
| 修正前（算 tool_use block、裸 `>=`） | 29 | 25% | 18 | 11 |
| 修正後（算 shell 指令、翻倍節流） | 7 | 6% | 1 | 6 |

29 次裡有 22 次是對正常行為開罵——多數是 G1 在罵那些早就把指令批次進同一個 Bash call
的輪次。拿掉它們沒有代價：兩臂都是 8/8 有產出、recall 98–99%。

前面的 arm B 顯示 deep 在真正序列相依的工作上正確地無視了 G1／G3。反應是對的，但也代表
「在真的能批次的工作上會不會聽話」仍未測到。

用 `proxy/test-loop-guard.mjs` 驗（13/13，原本 7/7）、把出貨版的 `shellUnits()` 抽出來
重跑同一份 77 session 語料驗（35.8% / 4.27 / p90 4，文件數字與執行中的程式碼一致），
再加四趟實跑 `deep-run`：

| Arm | 設定 | 結果 |
|---|---|---|
| A | 預設 | 7 輪、**0 次觸發**——deep 把任務收成 shell 迴圈，本來就沒有退化可罵 |
| B | `SINGLES=2 ROUNDS=3` | 23 輪、**13 次觸發**（G1＋G3），答案仍正確 |
| C | `NARRATION=400`、harness 開 | 5 輪、**0 次觸發**——文字寫進檔案，不在 assistant text 裡 |
| D | `NARRATION=400`、harness 關 | 12 次請求、5,141 字旁白、**1 次觸發**（累積 2,088 時）——翻倍節流擋住了，舊的 `>=` 會從越線那輪起每輪都噴 |

實跑確認了兩件單元測試做不到的事。第一，guard 用的 `role:"system"` 通道是 Claude Code
本來就在用的——dump 出來的請求內容裡看得到它自己的 token 預算通知走同一條路。第二，
**harness 開著時 deep 整趟只寫 419～688 字旁白**，所以 `DC_GUARD_NARRATION` 預設 3000
實際上不會觸發；G2 是 harness 被關掉或被無視時的保險，不是日常控制。

行為上的**改善**仍未成立——A/B 每組只有 n=2，被雜訊蓋過。arm B 另外顯示 deep 在真正
序列相依的工作上正確地無視了 G1／G3，反應是對的，但也代表「在真的能批次的工作上會不會
聽話」還沒測到。

**指標修正。** 第一版用 `tool_use` block 數算，得到「87% 單發輪」。這個指標是錯的：
同一個 Bash call 用 `;`、`&&`、`||` 或換行串起來，本來就已經是批次。改算 shell 指令數
重測 77 個 session、1,780 輪後，真正只做一件事的輪次只有 35.8%（平均 4.27 條指令／
輪）——block 數高估了問題 2.5 倍。guard 現在改算 shell 指令（`shellUnits()`，引號與
heredoc 內不計），`DC_GUARD_SINGLES` 由 3 調到 4：真正單指令連續段的 p90 就是 4，舊門檻
會對 62% 的連續段開罵，其中多數早就批次過了。

`DC_GUARD_NARRATION` 另有實際缺陷——`narration >= budget` 一旦超過就**每輪都觸發**
（最糟的 session 會噴 240 次）。現在改成每翻倍觸發一次：session 覆蓋率一樣是 28/77，
最多 6 次。

機制已由 `proxy/test-loop-guard.mjs`（13/13，原本 7/7）與實跑 proxy log 驗證。行為上的
**改善**仍未成立——A/B 每組只有 n=2，被雜訊蓋過。

# 2026-09-12

repo 建立，來源收攏自 agent-tools/.claude/.deepclaude。

Repo created; sources consolidated from agent-tools/.claude/.deepclaude.

agent-tools/sbin/deep-run 退役，唯一來源為本 repo。agent-tools/sbin/deep-run retired; this repo is the sole source.
repo 併入 royalskynet/deepclaude 頂層 `deep-agent/`（git subtree，歷史保留）；royalskynet/deep-agent 與 `~/dev/deep-agent` 刪除。symlink 改指 `~/.deepclaude/deep-agent/`。

Merged into royalskynet/deepclaude as top-level `deep-agent/` (git subtree, history kept); royalskynet/deep-agent and `~/dev/deep-agent` deleted. Symlinks now point at `~/.deepclaude/deep-agent/`.
