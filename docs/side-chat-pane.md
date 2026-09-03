# Side Chat Pane（把侧边聊天弹到新窗口）— 需求记下，暂不落地

目标对应 [功能对照.md](../功能对照.md) §10：对着正在跑的 Agent pane 一键再起一个 **完整的侧边聊天窗口**。新窗口里可以审阅、询问已有 session 和正在跑的 session。要对齐的是 Cursor / Codex App / Devin 那种独立 side chat 面板。

覆盖的 Agent 面：Claude Code、Codex、Cursor（GUI 与 CLI）、Grok、Agy，以及 Devin / Pi 作对照。不要按某一个 Agent 裁需求。

**结论（2026-09-03）：需求记下。不装现成插件。** 各家「侧边聊天」不是同一种实现。CLI 的 `/btw` 多数是同进程 overlay，弹不到另一个 Herdr pane。GUI 的 side chat 也不是 durable fork。社区里最像的是 Pi 扩展 `pi-herdr-btw`，不是 Herdr 插件，也只服务 Pi。Herdr 插件市场做的是 fork / 交接 / 互聊 / 审 diff。

调研日期 2026-09-03。未装下列任何插件或 Pi 扩展。

---

## 要的是什么

GUI Agent 工具已经做成这样：主 Agent 在干活，旁边一块 **完整聊天**（可多轮、有自己的 transcript），主线程不停、主对话不被污染。

Herdr 里希望同样的东西变成 **一个真 pane**：

1. 焦点在某个 Agent pane 上，快捷键立刻 split 出一个新 pane。
2. 起的过程复用该 Agent **已有的** btw / side chat 语义，不是 `herdr agent start` 一个空白会话，也不是把主任务 fork 走。
3. 新 pane 里是完整侧边聊天，不是同一 TUI 里那块可关掉的 overlay。
4. 在这个侧边聊天里，可以审阅、追问 **当前这个 session、别的已有 session、正在跑的 session**。

不是：

- 同一 pane 里敲 `/btw` 弹出的一次性面板。
- `/fork`、`--fork-session`、`codex fork` 那种把 transcript **复制进新 session 并显示出来** 的分叉。
- catchup / vaultr 式交接、停车、按 workspace 列历史（那是 §9）。
- 官方 `prefix+g` 的 pane 树，或空白 `herdr agent start`。
- 人在 pane 里标 git diff（reviewr / hunk-diff / Plannotator，那是 §6）。

---

## 实现到底是 fork，还是新空白 Agent + 注入路径？

两边都不是唯一答案。各家至少分成四类。**GUI 要对齐的那一类，既不是 durable fork，也不是只把 session 路径塞进提示词。**

### 1. 同进程 one-shot overlay：不新建 session

父对话的 messages 当这次 API 调用的上下文；问答 **不写回** 主 messages 数组；无工具或工具被掐掉；UI 是 overlay。没有新的 session id，也没有第二个进程。

| 面 | 命令 | 机制 | 出处 |
|---|---|---|---|
| Claude Code CLI | `/btw` | 并行一次 API 调用（主 loop 不插队）；`tool_choice: none` + system reminder「NO tools」；完整父对话可见，正在写的那条回复除外；单轮，不能 follow-up；overlay。官方定义为 subagent 的逆运算：全上下文、零工具。overlay 里按 `f` 才把这轮 Q&A fork 成 **同进程** 后台 subagent。复用父对话 prompt cache，额外成本很小。 | [Interactive mode](https://code.claude.com/docs/en/interactive-mode)；[Thariq 2026-03-10](https://x.com/trq212/status/2031509303870501210)；逆向整理见 [blackanger](https://x.com/blackanger/status/2031737194910761396) |
| Grok TUI | `/btw` | aside，不进主 turn；dismissible panel（minimal 模式写进 scrollback）。不是新 session。社区 `superagent-ai/grok-cli` 的同名实现是 `askSideQuestion`：无工具 one-shot、浓缩父对话尾巴、不改主 history——官方 Grok Build 文档没写到这个粒度，但产品行为一致。 | [Grok slash commands](https://github.com/xai-org/grok-build/tree/main/crates/codegen/xai-grok-pager/docs/user-guide)；[grok-cli #264](https://github.com/superagent-ai/grok-cli/pull/264) |
| Cursor CLI | `/btw`（2026-04 QoL） | 不打断当前 run 的旁问。和 3.11 GUI 的 Side chat **不是同一个东西**。 | [Cursor 2026-04-20](https://x.com/cursor_ai/status/2046324136377721128) |
| Agy | `/btw` | 后台旁问；临时 overlay；关掉即消失；只读上下文，不能写文件 / 跑命令。和 `/fork`（克隆整段对话、切到新 session）分开。 | [Antigravity CLI reference](https://antigravity.google/docs/cli-reference)；[conversations](https://antigravity.google/docs/cli/conversations) |
| Pi 社区 overlay | `/btw`（`Fatih0234/btw` 等） | shadow agent / overlay；复用父 prefix 吃 prompt cache；不写主历史。和下面的 `pi-herdr-btw` 不是同一条。 | [Fatih0234/btw](https://github.com/Fatih0234/btw) |

同类（本环境不用，只说明 `/btw` 在 CLI 圈是 overlay 惯例）：OpenClaw `/btw` 是 snapshot + 无工具 one-shot，不写 history；对 Codex harness 才会 ephemeral fork 子 thread。Hermes `/btw` 是 snapshot + 后台 no-tools agent。Gemini CLI、Copilot CLI 当时还是 feature request。

这类 **没法弹到新 Herdr pane**：它画在当前 PTY 里。往原 pane send-keys `/btw` 不是「新窗口」。

### 2. Ephemeral fork：协议上是 fork，UI 上把父 transcript 藏起来

Codex `/side`（`/btw` 同义）走这条。PR [#18190](https://github.com/openai/codex/pull/18190)（2026-04-19 合入）写得很清楚：

- 实现是 **ephemeral fork**：新建一条 side thread，一次一条。
- 父历史进模型，但加 hidden developer guardrails：**inherited history 只当 reference**，默认不要改 workspace。
- UI **隐藏父 transcript**（commit：`Hide parent transcript in side conversations`）。看起来像空聊天，模型其实看得到父对话。
- Esc / Ctrl+C 回父线程；后来 [#35011](https://github.com/openai/codex/pull/35011) 加了 `ctrl-/`（`toggle_side_conversation`），可在 side 和父之间切而不关。
- 常不落盘。Desktop 上 side chat 没有 rollout 文件，再 `thread/fork` 会失败（[#22001](https://github.com/openai/codex/issues/22001)）。app-server 的 `thread/fork` 有 `ephemeral: true`（[#14248](https://github.com/openai/codex/issues/14248)）。
- 官方文档：[/side 是 ephemeral fork，父线程状态仍可见](https://developers.openai.com/codex/cli/slash-commands)；`/fork` 是 durable 分叉。两条分开写。

这是 fork，但 **不是** `codex fork <id>` 那种 durable、父对话会出现在新 transcript 里的分叉。`codex fork` 仍在同一个 TUI 进程里切 thread，也不是新 Herdr pane。

### 3. 新的持久对话 + 父历史当 hidden reference：不是 fork

Cursor GUI Side chat（3.11，2026-07-10，`/side` / `/btw` / 面板加号）走这条。官方文档原话：

> The parent's conversation history is copied in as **reference context** for the model. That history **does not appear** in the side-chat transcript.
>
> Forking copies the parent conversation into a new chat. A side chat only seeds the model with the parent history as hidden context. It does not reproduce the parent transcript. **A side chat is a parallel thread, not a fork.**

出处：[Side chats](https://cursor.com/help/ai-features/side-chats)、[changelog 3.11](https://cursor.com/changelog/side-chat)。Cursor 员工 [Tibor](https://x.com/tibor_tee/status/2088576378119577728)：*We seed the new chat with the parent thread as context*。回灌主对话用 `@` 提 side chat，和 `@` 旧聊天一样给 transcript 引用（[Matt Shwery](https://x.com/mshwery/status/2075833172471013792)），不是把两段历史并成一段。

工程含义：

- 新建一个 **durable** 的完整 Agent 对话（可多轮、默认可读文件/搜索；需要时也能改，只是默认偏读）。
- 父历史复制进 **模型上下文**，不复制进 **可见 transcript**。
- 不是「空 Agent + 只传父 session 路径」。
- 不能嵌套；绑在父 Agent 上；目前 local-only，Cloud Agents 没有。
- 选中文本 / diff → **Ask in Side Chat**；快捷键 Shift+Cmd+S / Shift+Ctrl+S。

这是 GUI 目标形态。Cursor CLI 的 `/btw` 仍是 overlay；CLI 和 Agents Window **不共享 chats**（[论坛](https://forum.cursor.com/t/i-dont-see-a-chat-from-cli-in-agents-window/161787)）。Herdr 里的 Cursor pane **没有** 这块独立 panel。

### 4. 新面板 + 父 session 快照，只读工具

Devin Side chats：`/btw`、消息 hover、加 tab。独立 panel，带「到那条消息为止」的 session context。只读：能搜/读代码，不能改文件、跑命令、改主 session 的工作。主 session 一直跑。

出处：[Devin Session Tools](https://docs.devin.ai/work-with-devin/devin-session-tools)；[Nader Dabit 2026-08-14](https://x.com/dabit3/status/2088412013076578410)。

更像带快照的子对话，不是把 worklog fork 一份去继续干活。

---

## 对照（不要混）

| | 可见 transcript | 模型看到的父历史 | 新 session / thread | 工具 | 主任务 |
|---|---|---|---|---|---|
| Claude / Grok / Agy / Cursor CLI `/btw` | 无（overlay） | 有（当次调用） | 无 | 无 | 不停 |
| Codex `/side` | 只有 side 自己的；父的藏起来 | 有（fork 来的，标成 reference） | 有，常 ephemeral | 有，默认别改 workspace | 不停 |
| Cursor GUI Side chat | 只有 side 自己的 | 有（hidden reference，不是 fork 出来的可见副本） | 有，durable | 有，默认偏读 | 不停 |
| Devin Side chat | 独立 panel | 到锚点为止的 session | 子对话 / 面板 | 只读 | 不停 |
| `codex fork` / `claude --resume --fork-session` / `grok --resume --fork-session` / `agy /fork` | **父对话复制进去并显示** | 有 | 有，durable | 完整，会接着干活 | 原 session 留下，但这是分叉不是 side chat |

「只把父 session 路径写进第一条 prompt」是 Herdr 自己的近似，**没有哪家 GUI 是只传路径、不把父对话内容（或快照）喂给模型的。** Durable native fork 会把父对话显示在新窗口里，和 Cursor / Codex App / Devin 都不一样。

Claude `--fork-session` 还有一层：从另一个终端 fork 读的是磁盘上上次 flush 的 JSONL，正在跑的 live 上下文可能落后（[#44684](https://github.com/anthropics/claude-code/issues/44684)）。`/fork` 在进程内才是内存态。

---

## 为什么 CLI overlay 不能直接变成新窗口

Herdr 的一个 pane = 一个 PTY = 通常一个 Agent 进程。GUI 的 side chat 是 **另一个 conversation 对象 + 另一块 panel**。CLI overlay 画在同一个进程里。

要进新 pane，必须能 **另起进程**。今天没有哪家 CLI 提供 `agent side-chat --from <session-id>` 这种独立进程入口。能另起进程的是 durable fork，语义不对。

Claude 用户提过「`/fork` 开到新 terminal tab」（[#24123](https://github.com/anthropics/claude-code/issues/24123)），官方没做；那也是 fork tab，不是 side chat pane。

---

## 社区调研（没有跨 Agent 的现成解）

按接近程度，不是按能不能装。索引对照过 [herdr-plugins-directory](https://github.com/MIDO-ruby7/herdr-plugins-directory)（2026-09-03，约 936 个）和 [awesome-herdr](https://github.com/yigitkonur/awesome-herdr)。

### 最像：把 side thread 弹到新 Herdr pane

这些是 **Pi 扩展**，不是 `herdr plugin install`。

| 方案 | 形态 | 覆盖 | Windows | 和需求的差 |
|---|---|---|---|---|
| [oscabriel/pi-herdr-btw](https://github.com/oscabriel/pi-herdr-btw) 0.3.1（`pi install npm:pi-herdr-btw`） | `/btw` → `herdr pane split` + `herdr agent start --kind pi --pane`。快照父 session（compaction-aware）；继承 cwd / model / thinking；父 transcript 不改；默认可带工具、可多轮、可改初稿。`/btw merge` 把侧边 user/assistant 回合打成一段可见消息送回父 pane（父忙就等 settle）。子进程默认重放父 system + native messages 以吃 Anthropic prompt cache。 | 只 Pi | 未声明；启动走官方 `pane split` / `agent start` | **语义最贴。** 子进程是静态快照，看不到父后来的活动；共享 cwd，开了工具会改同一份文件。不能给 Claude / Codex / Cursor / Grok / Agy 用。 |
| [@maxedapps/pi-herdr-sidetrack](https://www.npmjs.com/package/@maxedapps/pi-herdr-sidetrack) 0.1.1 | `/sidetrack <prompt>` 把当前 Pi 对话 **克隆** 到右侧 50/50 pane；独立 session 文件；继承 branch / model / thinking / compaction。只拷已完成的 tip，进行中的 assistant 文本不进快照。 | 只 Pi | 未声明 | 更像 fork：继承整段对话，不是 hidden-reference 的空侧边聊天。 |

`pi-herdr-btw` 证明「新 pane + 父上下文快照、父 transcript 不动」在 Herdr 里能走通，但只做了 Pi。

### 附近：fork / 交接 / 互聊 / 审 diff（Herdr 插件）

| 方案 | 形态 | Windows | 覆盖 | 结论 |
|---|---|---|---|---|
| [dmangla3/herdr-fork-from-message](https://github.com/dmangla3/herdr-fork-from-message) 0.3.0 | 焦点 pane 的 Codex / Claude native fork 到新 tab / split / workspace，再进 native 早先消息 picker。`codex fork <id>` 或 `claude --resume <id> --fork-session`。不改 transcript 文件。 | 无（`macos`/`linux`，`python3`） | Codex、Claude | **不装。** durable fork。 |
| [mkdir700/herdr-config](https://github.com/mkdir700/herdr-config) 里的本地 `herdr-fork` | `prefix+shift+z`：焦点 Codex `codex fork <id>` 到右 split；后台把新 session id 挂回 pane | 视脚本而定 | 只 Codex | 个人配置里的 fork，不是 side chat。 |
| [calebcauthon/herdr-agent-copy-paste-fork](https://github.com/calebcauthon/herdr-agent-copy-paste-fork) | 复制粘贴 transcript 到新 pane | — | 泛 | 手工 fork。 |
| [wilbeibi/herdr-catchup](https://github.com/wilbeibi/herdr-catchup) | `summary` / `fork` / `handoff` / `send` / `ask`。`ask` 把 transcript 写成文件，prompt 给 **已经在跑** 的另一个 pane 做一轮审阅。源 session 来自 `herdr agent get` 的 session id。 | 无（Linux/macOS，herdr ≥ 0.7） | 读：Claude、Codex、OpenCode、Pi、Agy、Cline、Copilot、Cursor、Kimi。不读 Grok。 | **不装。** `ask` 不是弹出 side chat。 |
| [connerohnesorge/herdr-vaultr](https://github.com/connerohnesorge/herdr-vaultr) | 当前 pane 的 vault transcript / fork / 搜索 | 无 | Claude / Codex / Pi + vaultr | 翻已捕获会话。 |
| [aashishd/herdr-agent-messenger](https://github.com/aashishd/herdr-agent-messenger) | 活 pane 之间发短消息（call-sign）。Claude / Pi / OpenCode `/msg`，Codex `$herdr-agent-messenger:msg`。不共享完整对话。 | 无（Bash、Python、fzf） | Claude、Pi、Codex、OpenCode | 互聊，不是侧边窗口。 |
| [jeffory/herdr-walkietalkie](https://github.com/jeffory/herdr-walkietalkie) | 编排器把活派到别的 tab / worktree；文件交接 | — | Claude、OpenCode、Agy | 委派干活，不是旁问。 |
| [Elio2000/herdr-peer-review](https://github.com/Elio2000/herdr-peer-review) | `review-diff`：旁边起第二个 Agent（默认 `codex --sandbox read-only`）审 **uncommitted diff**。`consult`：空白 peer TUI 问答。peer 命令可换成 claude / cursor / grok。 | `peer.sh`，偏 Unix | 审的是 git，peer kind 可配 | **不装。** 审 diff，不是父 Agent Session。`consult` 是空白新 Agent。 |
| [persiyanov/herdr-reviewr](https://github.com/persiyanov/herdr-reviewr) | 人看 Agent diff，选行写备注发回 | 无 | Git worktree | 人审代码。§6 已否。 |
| [jhochenbaum/herdr-hunk-diff](https://github.com/jhochenbaum/herdr-hunk-diff) | hunk 里标 Agent 改动，备注发回写代码的那个 Agent | 有（`review-windows` pane） | Git | 人审代码，不是 Agent 侧边聊天。 |
| 官方 `herdr agent start` | 空白新 Agent，占已有 shell pane | 有 | 已识别的 kind | 没有父 session 上下文。 |

官方讨论 [#741](https://github.com/herdrdev/herdr/discussions/741) 要的是 `@agent` 委派 / 流水线，不是 side chat 面板。

其它名字像、其实不是：

| 方案 | 实际是 |
|---|---|
| [hcaiano/skills](https://github.com/hcaiano/skills) `herdr-pair` | 同一 tab 里 Claude 和 Codex 配对协作 |
| [AndrewJacop/pi-herdr](https://github.com/AndrewJacop/pi-herdr) | Pi 当编排器，去 spawn 别的 agent pane（测过 Windows） |
| [leonho/herdr-agent-inbox](https://github.com/leonho/herdr-agent-inbox) | 活 agent inbox，不是侧边聊天；§9 |
| [douglascorrea/herdr-agent-inbox](https://github.com/douglascorrea/herdr-agent-inbox) | 过往 session 列表；§9 |

没有哪家 Herdr 插件对 Claude / Codex / Cursor / Grok / Agy 做同一套「新 pane + 父历史当 hidden reference」。最接近的实现在 Pi 扩展里，不在 Herdr 插件市场里。

不要为了「能再起一个 Agent pane」去装 fork-from-message / catchup / peer-review。不要和 §9 的 inbox / session-digger 叠。不要把 `pi-herdr-btw` 装到非 Pi pane 上指望它通用。

---

## 以后若做成 Herdr 动作，产品形状

一个快捷键，对 **当前焦点那种 Agent** 做同一件事，按 kind 分 adapter，不要写死一家。形状可以对着 `pi-herdr-btw`：split + 新进程 + 父上下文快照 + 父 transcript 不动；但要按 kind 换启动命令和 transcript 路径，并且侧边角色是 hidden reference，不是把父对话显示出来。

```text
焦点 Agent pane
  → herdr agent get：kind + session id（对应 integration 要已装）
  → pane split（宽则 right，窄则 down；cwd 跟父 pane）
  → 新 pane 里起 **同 kind 的新进程**（空 session，不是 durable fork）
  → 把父 session 的身份和内容喂进去：session id、transcript / export 路径、必要时 live 快照
  → 第一条说明：你是 side chat；父历史是参考，不要画进你自己的 transcript；
     不要接管主任务；可以 herdr agent list / read / prompt 去问正在跑的 session
```

这是在 **没有独立 side-chat 进程入口** 时，对 Cursor GUI / Codex `/side` / Devin 的近似：

- 不是 `codex fork` / `--fork-session` / `agy /fork`（那些会把父对话显示出来，并且常会接着干活）。
- 不是只传路径、不喂内容（GUI 都把父对话或快照给了模型）。
- 不是往原 pane send-keys `/btw`。

按 kind 的 adapter 职责：

| kind | 原 pane 旁问（现行） | 新 pane 不要用 | 新 pane 应近似 |
|---|---|---|---|
| Claude | `/btw` overlay | `claude --resume --fork-session` | 新 `claude` + 父 JSONL / export 当 hidden reference |
| Codex | `/side` 同进程 ephemeral fork | `codex fork <id>` | 新 `codex` + 父 rollout 当 reference；若以后 CLI 能 `ephemeral fork` 出进程再换 |
| Cursor | CLI `/btw` overlay；GUI 才有真 Side chat | GUI fork chat | 新 `cursor` agent + 父 transcript 当 hidden reference（CLI 没有 GUI 那块 panel） |
| Grok | `/btw` overlay | `grok --resume --fork-session` | 新 `grok` + 父 `updates.jsonl` / `grok export` 当 reference |
| Agy | `/btw` overlay | `agy /fork` | 新 `agy` + 父 conversation 当 reference |
| Pi | overlay 扩展，或 `pi-herdr-btw` | `/sidetrack` 那种整段克隆 | 已有 `pi-herdr-btw`；通用插件不必重做 Pi，或直接调它 |

审正在跑的 session 不必另做协议。新 pane 里的 Agent 用 herdr skill：`herdr agent list`、`read`、`prompt`。插件只要在注入里写清可以读哪些活 pane。

某家以后若提供独立进程的 side-chat 入口，adapter 换成那条，不要继续用「空进程 + 喂文件」的近似。

---

## 现行（不是插件）

主任务进行中的旁问：在 **原 pane** 里用该 Agent 自己的 `/btw` 或 `/side`。

要一块完整窗口：现在没有一键。手动 split 再起同 kind 的新 Agent，自己把父 session 说明清楚——这已经是近似，不是 native side chat。只跑 Pi 时可以看 `pi-herdr-btw`，不要指望它覆盖其它 kind。

要问旁边正在跑的 Agent：任意带 herdr skill 的 pane 里 `herdr agent list` / `read` / `prompt`。

未再启动前先读这一页。不要默认：

```text
herdr plugin install dmangla3/herdr-fork-from-message
herdr plugin install wilbeibi/herdr-catchup
herdr plugin install Elio2000/herdr-peer-review
pi install npm:pi-herdr-btw          # 除非当前就是 Pi pane，且接受只服务 Pi
```

不要把 durable fork 当成 side chat 的实现。
