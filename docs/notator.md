# Notator（Windows）

本机批注层。目标对应 [功能对照.md](../功能对照.md) §6：在 diff / 文档 / 终端文本上标注，并把反馈送回**当前那条 Agent 对话**。

Windows 上不走 Herdr 内嵌浏览器。三条线：

| 审什么 | 用什么 | 反馈怎么回 Agent |
|---|---|---|
| Git / P4 diff、URL、跑着的本地网页 | Chrome 里的 **Plannotator** | 谁启动 `plannotator` 并阻塞等 stdout，谁就是会话 |
| Markdown / 计划 / Agent 刚说的那段 | Herdr pane 里的 **plannotator-tui** | 点 Send / `E`，走 `herdr agent prompt` 写进目标 pane |
| 终端里圈中的一段字 | **herdr-annotate** | 贴到 focused pane / 剪贴板 |

---

## 选型

| 方案 | 结论 |
|---|---|
| [herdr-plannotator](https://github.com/plannotator/herdr-plannotator) + [herdr-browser](https://github.com/ogulcancelik/herdr-browser) / [terminal-browser](https://github.com/zenbu-labs/terminal-browser) | **不装。** 清单只有 linux/macos，依赖 Kitty graphics。Windows Terminal 走不通；官方只测过 WezTerm + WSL。 |
| [herdr-reviewr](https://github.com/persiyanov/herdr-reviewr) | **不装。** 无 Windows，且绑 Git worktree，P4 workspace 不能 fork 它。 |
| [Plannotator OSS](https://docs.plannotator.ai/open-source/) | **主力（diff / URL / 本地网页）。** Windows 官方安装器；`plannotator review` 认 Git 和 Perforce。 |
| [herdr-annotate](https://github.com/plannotator/herdr-annotate) | **附件。** 终端选中文本；Windows 为 preview。官方 Full 安装把 TUI pane 锁在 macos/linux。 |
| [plannotator-tui](https://github.com/plannotator/plannotator-tui) | **Markdown 在终端里审。** v0.6.0 已有 `x86_64-pc-windows-msvc` 官方包（懒加载目录树）。Herdr 侧用本仓库 [plugins/plannotator-tui](../plugins/plannotator-tui) 垫一层，等上游 `herdr-annotate` 自己接 Windows。 |

Chrome 批注：**谁启动 `plannotator` 并阻塞等 stdout，谁就是会话。** 自己在空终端跑 `plannotator review`，没有任何 Agent 会收到结果。

TUI 批注：必须在 Herdr 里开（`HERDR_ENV=1`）。Send 把编号批注写进目标 Agent pane，**不要**让 Agent 阻塞等进程退出。

---

## 本机已落地（2026-08-31）

| 组件 | 版本 / 位置 |
|---|---|
| Herdr | 0.8.2，`%LOCALAPPDATA%\Programs\Herdr\bin\herdr.exe` |
| Plannotator | 0.27.9，`%LOCALAPPDATA%\plannotator\plannotator.exe` |
| plannotator-tui | 0.6.0，`%LOCALAPPDATA%\plannotator\plannotator-tui.exe`（同目录已在用户 PATH） |
| Bun | 1.4.0（winget `Oven-sh.Bun`） |
| herdr-annotate | 插件 id `annotate` 0.3.0，`herdr plugin install plannotator/herdr-annotate` |
| plannotator-tui 插件 | 插件 id `plannotator-tui`，`herdr plugin link` 本仓库 `plugins/plannotator-tui` |
| Perforce CLI | 已有 `p4`；本机 client `xucongwei_development`，root `E:\Project` |
| 系统浏览器 | Chrome 151 |

Skill 装在：

- `%USERPROFILE%\.agents\skills\`（Grok / Codex 等共用）：Plannotator 安装器管理的 `plannotator`、`plannotator-review`、`plannotator-annotate`、`plannotator-last`，以及本仓库管理的 `plannotator-tui`
- `%USERPROFILE%\.claude\skills\`：同上五份

五份 skill 均为**仅显式调用**：`disable-model-invocation: true`，Codex 版本另用 `agents/openai.yaml` 的 `allow_implicit_invocation: false`。模型不要因为写完计划、改完代码或看到 Markdown 就主动打开 Chrome / TUI；只有人明确调用对应 skill 时才加载并执行。Herdr 快捷键和插件 action 不经过 Agent skill，不受此设置影响。

Plannotator 更新会替换它管理的四份 skill。安装或升级后保留上游正文，只复核显式调用元数据；不要在本仓库维护它们的内容分叉。`plannotator-tui` 的正文和调用策略以本仓库为准。

统一策略脚本只同步本仓库 TUI skill，并给已安装 skill 补显式调用元数据；不维护 Plannotator 上游正文：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/set-notator-skills-explicit.ps1
```

---

## 安装（可复现）

在一台新的 Windows Herdr 机器上按这个顺序。需要 Git、Chrome、已装好的 Herdr ≥ 0.8.0。P4 工作流还需要 `p4` 在 PATH 上。

### 1. Bun

```powershell
winget install --id Oven-sh.Bun -e --accept-package-agreements --accept-source-agreements
```

装完重开终端。确认：`bun --version`。

若 Herdr **server 是在装 Bun 之前启动的**，当前进程 PATH 里没有 `bun`，插件会报 `program not found`。临时垫片（Herdr 升级可能冲掉；重启 Herdr 后用户 PATH 已有 Bun 即可删）：

```bat
:: %LOCALAPPDATA%\Programs\Herdr\bin\bun.cmd
@echo off
"%LOCALAPPDATA%\Microsoft\WinGet\Packages\Oven-sh.Bun_Microsoft.Winget.Source_8wekyb3d8bbwe\bun-windows-x64\bun.exe" %*
```

路径以本机 `where.exe bun` 为准。

### 2. Plannotator

官方脚本：

```powershell
irm https://plannotator.ai/install.ps1 | iex
```

本机 Clash mixed 端口 `127.0.0.1:7897` 下，Windows PowerShell 的 `Invoke-WebRequest` 会失败（套接字未连接）。`curl.exe` 可以走同一代理。做法：先 `curl.exe -fsSL https://plannotator.ai/install.ps1 -o $env:TEMP\plannotator-install.ps1`，再在同一会话里用 `curl.exe` 包一层 `Invoke-WebRequest` / `Invoke-RestMethod`，然后：

```powershell
& $env:TEMP\plannotator-install.ps1 -NonInteractive -NoExtras
```

不要加 `-Minimal`：完整安装才会写入 skill。不要加 `-Extras`（compound / setup-goal / visual-explainer 默认不装）。

校验：

```powershell
plannotator --version    # 期望 0.27.9 或更新
plannotator review --help
```

新开的终端才能看到 `plannotator`（安装器改的是用户 PATH）。

### 3. herdr-annotate

```powershell
herdr plugin install plannotator/herdr-annotate --yes
```

Windows 会跳过 `bash scripts/fetch-plannotator-tui.sh`。官方插件在 Windows 上只有 `capture` / `copy-context` / `manage`。`open` / `last` / `open-link` 仍标 macos/linux，文档审阅走下面第 4 步的垫片。

在 `%APPDATA%\herdr\config.toml` 增加（本机已写）：

```toml
[[keys.command]]
key = "prefix+a"
type = "plugin_action"
command = "annotate.capture"
description = "annotate selected terminal text"

[[keys.command]]
key = "prefix+shift+a"
type = "plugin_action"
command = "annotate.copy-context"
description = "copy annotations as agent context"

[[keys.command]]
key = "prefix+m"
type = "plugin_action"
command = "annotate.manage"
description = "manage annotations"
```

然后：

```powershell
herdr config check
herdr server reload-config
```

冒烟：`herdr plugin action invoke manage --plugin annotate`，日志 status 应为 `succeeded`。

### 4. plannotator-tui（Windows 垫片）

官方 [plannotator-tui](https://github.com/plannotator/plannotator-tui) v0.6.0 已经发 Windows 包（`plannotator-tui-x86_64-pc-windows-msvc.exe`）。`herdr-annotate` 的 fetch 脚本还没有 Windows 分支，pane 命令也是 `sh`/`bash`，所以不改官方插件，另 link 本仓库的薄插件：下载官方二进制，按 `herdr-perforce` 的方式用 PowerShell + `HERDR_PLUGIN_ROOT` 拉起。

在 **herdr-dev-env** 仓库根目录：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File plugins/plannotator-tui/scripts/fetch.ps1
herdr plugin link "$PWD/plugins/plannotator-tui"
```

`fetch.ps1` 会：

1. 按 `plugins/plannotator-tui/plannotator-tui.version`（当前 `0.6.0`）下载并校验 sha256
2. 写入插件 `bin/plannotator-tui.exe`（不进 git）
3. 再拷一份到 `%LOCALAPPDATA%\plannotator\plannotator-tui.exe`，跟 `plannotator.exe` 同目录，用户 PATH 已经有这条

校验：

```powershell
plannotator-tui --version    # 期望 0.6.0
herdr plugin list            # 应有 plannotator-tui (Plannotator TUI) enabled [local:…]
```

在 `%APPDATA%\herdr\config.toml` **接着**增加（本机已写）：

```toml
[[keys.command]]
key = "prefix+o"
type = "plugin_action"
command = "plannotator-tui.open"
description = "review documents in this folder"

[[keys.command]]
key = "prefix+shift+o"
type = "plugin_action"
command = "plannotator-tui.last"
description = "review the agent's last reply"
```

然后：

```powershell
herdr config check
herdr server reload-config
```

把显式 skill 拷到 Agent 能读的位置（本仓库有一份）：

```powershell
$src = "plugins/plannotator-tui/skills/plannotator-tui"
Copy-Item -Recurse $src "$env:USERPROFILE\.agents\skills\plannotator-tui" -Force
Copy-Item -Recurse $src "$env:USERPROFILE\.claude\skills\plannotator-tui" -Force
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/set-notator-skills-explicit.ps1
```

冒烟（不要在当前 Agent pane 上 overlay，会盖住对话）：

```powershell
plannotator-tui --snapshot docs/notator.md 100 24 0
herdr plugin pane open --plugin plannotator-tui --entrypoint doc --placement tab --workspace <闲置 workspace> --cwd $PWD --env "PLANNOTATOR_TUI_FILE=$PWD\docs\notator.md" --no-focus
```

打开后 footer 应有 `notator.md · 0 annotations`。看完关掉那个 tab。

v0.6.0 起 TUI 只列当前这一层目录（展开才往下读），并跳过 `node_modules`/`target`/`vendor`/`dist`/`build`/`out`/`__pycache__`/`venv`。这份名单编译在官方 exe 里，垫片改不了。`prefix+o` 额外走 `scripts/open.ps1`：源码大库（有 `src`/`Engine`/`node_modules` 等）且存在 `docs`/`documentation`/`plans` 时，打开那个子目录。

可选：`%APPDATA%\plannotator-tui\config.toml` 里改 `[herdr] placement`（`overlay` 默认 / `split` / `popup`）。`plannotator-tui config` 打印生效值。`[tree]` / extra skip 这类键不存在，写了会启动失败。

---

## 日常怎么用

### 把批注送回某个 Agent Session

在**那条正在干活的 Agent 对话**里让它开 Plannotator，不要另开终端自己跑。

Grok 示例（Chrome，Agent **阻塞**等 stdout）：

- `/plannotator-review` 或「用 Plannotator 审一下当前改动」
- `/plannotator-annotate plan.md`
- `/plannotator-last`（审刚说的那段）

Agent 执行对应命令并阻塞。Chrome 打开后你点 **Send Feedback** 或 **Approve**。进程退出，stdout 回到**同一次**工具调用，Agent 按批注继续。不要把浏览器内容复制进聊天。

Grok 示例（TUI，Agent **开完就结束本轮**）：

- 「用 plannotator-tui 审一下 `docs/plan.md`」
- 或 Agent 自己写完计划后跑 `plannotator-tui herdr open docs/plan.md`

TUI 在 Herdr 里打开。你拖选 / `v`，`a` 👍 · `c` 💬 · `d` ✗，然后 **Send** 或 `E`。批注成为目标 pane 里 Agent 的下一条消息。`q` 关掉。Agent 不要 poll、不要等进程退出。

**文件夹模式的 Send 范围比屏幕上看到的大，容易把旧批注塞给新 Agent。** 已复现：footer / 按钮可以是 **0 annotations**，折叠的目录上也没有「下面有批注」的数字（懒加载：没展开就不往子树加总），点 `E` 却仍把隐藏文件上的旧批注发给当前 Agent。原因是两套逻辑：树上的计数只看**当前列出来的行**；Send 从 0.5 起改成扫这个 Git 仓库在 `~\.plannotator\clients\plannotator-tui\annotations\<project>\` 里**所有 `annotations` 还非空的 md**（记录带着文件路径，不依赖树是否展开）。垫片改不了 exe 里的导出。本机 Herdr toast 是 **off**（说明见 [toast.md](toast.md)），所以 `prefix+o` 打开目录且仓库里还有残留批注时，垫片弹 **Windows 对话框**，列出相对仓库根的路径。Ctrl-click 某一份 md 不会提示。不用重新编译插件。只想发正在看的那一份：Ctrl-click 那个 `file://…md`，或让 Agent 跑 `plannotator-tui herdr open 具体文件.md`（没有文件树，Send 只含这一份）。发完用 rail 的 `x` 清掉。

cwd 必须对：P4 审阅在 client view 里开（本机是 `E:\Project`）。在 Git 仓库目录跑会走 Git，不会走 Perforce。

自己在终端跑 `plannotator review` / `plannotator-tui file.md` 也可以看，但没有 Agent 在等。TUI 在 Herdr 外面时 Send 只走剪贴板（OSC 52），不会 `herdr agent prompt`。

### Herdr 快捷键

| 键 | 动作 |
|---|---|
| `Ctrl+B` `A` | 给当前选中文字写备注 |
| `Ctrl+B` `Shift+A` | 复制全部备注为给 Agent 的 Markdown |
| `Ctrl+B` `M` | 管理备注 |
| `Ctrl+B` `O` | 用 plannotator-tui 审当前 pane 目录（文件树）。源码大库若有 `docs`/`plans`，垫片会先开那个子目录 |
| `Ctrl+B` `Shift+O` | 用 plannotator-tui 审 focused Agent 最近回复 |
| Ctrl-click `file://…md` | 用 plannotator-tui 打开那个 Markdown |

`Ctrl+B Shift+O` 读 **当前 focused Agent pane**（只打开最新一条助手回复）：

| Herdr 认的 agent | 进程名（Windows） | last 从哪读 |
|---|---|---|
| `grok` | `grok.exe`（也有一份 `~\.grok\bin\agent.exe`） | `~\.grok\sessions\<cwd-slug>\<session-id>\chat_history.jsonl` |
| `cursor` | `cursor-agent` / `cursor-agent.cmd` / 别名 **`agent`** | `~\.cursor\projects\<slug>\agent-transcripts\<id>\<id>.jsonl` |
| `claude` / `codex` / `pi` / `copilot` / `droid` | `codex.exe` 等 | 剥掉 `.exe`/`.cmd` 后交给官方 last |
| `agy` 及其它 | `agy.exe` 等 | `herdr agent read` 的近期屏幕。Agy 会话是 protobuf，垫片不解析 |

不要走官方 `plannotator-tui herdr last` 的默认路径：对不上 host 就会打开 `~\.claude\projects` 里别的仓库。`agent` 同时是 Cursor CLI 的别名和 Grok 目录里的一份 exe，以 Herdr 的 `pane.agent` 为准。

终端圈字、TUI 审 Markdown、Chrome 审 diff，是三条线。

### Perforce

`plannotator review` 在 Git 判定之后跑 `p4 info`，认当前 client root。默认看 default changelist 里打开的文本文件；二进制 opened 会跳过；没有 staging UI。编号 pending CL 在页面的 comparison 里选。

P4 的树 / Diff / Submit 仍归 `herdr-perforce`，Plannotator 不替代它。

---

## 刻意没做的

- **没把 Chrome 那三份 skill 改成模型可调用。** 需要 Agent 改完自动弹浏览器时，再跑安装器 `-Reconfigure`，或 `-ModelInvocable plannotator-review`。TUI skill 已经允许模型调用。
- **没改 herdr-annotate 上游，也没提 issue。** Windows TUI 是本仓库垫片。退役条件见下一节。
- **没装 Claude Code marketplace 插件。** 本机 `claude` 是损坏的 `claude-cac` 包装。`~\.claude\skills\` 已有文件；Claude 本体修好后在里面执行：
  ```
  /plugin marketplace add backnotprop/plannotator
  /plugin install plannotator@plannotator
  ```
  这才会接上 `ExitPlanMode` 自动计划闸门。
- **没改 Codex hook。** Windows 上官方仍标实验，安装器只打印了手动步骤。
- **没装 herdr-plannotator。** 内嵌 Browser pane 这条链路 Windows 不可用。

---

## 上游会不会直接支持；垫片何时卸

没有公开时间表。截至 2026-08-31：

| 层 | 官方现状 | 我们的判断 |
|---|---|---|
| `plannotator-tui` 二进制 | v0.6.0 已发 `x86_64-pc-windows-msvc.exe`；目录树懒加载，启动只列一层，跳过 `node_modules`/`target`/`vendor`/`dist`/`build`/`out`/`__pycache__`/`venv` | **已经支持。** 本机用的就是这份，不 fork TUI。跳过名单写死在二进制里，垫片加不进去。 |
| `herdr-annotate` Full | README 仍写 TUI「macOS and Linux today」；`[[build]]` / `doc` pane / `open` / `last` / Ctrl-click 都是 `platforms = ["macos","linux"]`；fetch 脚本没有 Windows 分支 | **还没接。** 插件本身标了 Windows，但只给圈字（Lite 那套）。二进制都有了，接 Windows 是自然下一步，仓库里没有 issue、没有日期。 |
| `plannotator-tui last` 的 host | 认 claude / codex / pi / omp / copilot / droid / hermes / opencode。不认 `grok` / `cursor`，也不剥 `.exe`/`.cmd`。对不上就**默认 Claude Code** | **短期不会 magically 变好。** Grok、Cursor CLI（`agent`）的 last 要一直留在垫片里，直到 `plannotator-tui-hosts` 合入。 |

所以：官方**很可能**会让 `herdr plugin install plannotator/herdr-annotate` 在 Windows 上也能 `prefix+o` 审 Markdown（那只是 fetch + 非 bash 启动）。**不要指望**同一天就能审 Grok / Cursor 的 last reply。那要改 `plannotator-tui-hosts`，或继续留 `scripts/last.ps1`。

**不要另开 `plannotator-tui-windows` 库。** 垫片不是 TUI fork，能扩展的只有启动层；`open` 会随官方 Windows 支持退役，长期只剩 `last.ps1`。继续放在 `herdr-dev-env/plugins/plannotator-tui`，新机器按本节安装。精力优先给上游 PR，而不是养第二个仓库。

本仓库垫片真正多出来的、卸官方插件也带不走的：

1. Windows 下用 PowerShell + `HERDR_PLUGIN_ROOT` 拉起官方 exe（和 `herdr-perforce` 同一套）。
2. `last`（`scripts/last.ps1`）：剥 `.exe`/`.cmd`；Grok / Cursor（CLI 名 `agent`）读各自 session 文件，只展示最新一条助手回复。
3. `open`（`scripts/open.ps1`）：`prefix+o` 落在源码大库（有 `Engine`/`src`/`node_modules` 等）且存在 `docs`/`documentation`/`plans` 时，把那个子目录交给 TUI，避免它为找第一份 Markdown 去 `list()` Intermediate。打开的是目录且该 Git 仓库在 `~\.plannotator\...\<project>\` 里还有未清空的批注时，弹 Herdr 通知（TUI 树上显示 0 也会发）。TUI 自己的跳过名单和 Send 范围加不了；Ctrl-click 具体文件和 Agent 显式路径不改。
4. Skill：`plugins/plannotator-tui/skills/plannotator-tui`，仅在人显式调用时加载；开完 pane 就结束本轮。

`herdr-annotate` 上游出现这些信号再退役 **open / Ctrl-click** 垫片：

- `herdr-plugin.toml` 里 `doc` / `open` / `open-link` / `markdown-file` 带 `windows`
- `scripts/fetch-plannotator-tui.sh`（或 `.ps1`）能装 `plannotator-tui-x86_64-pc-windows-msvc.exe`
- pane 命令不再依赖 `sh`/`bash`，或 Herdr 能在 Windows 上跑它
- 本机 `herdr plugin action list --plugin annotate` 能看到 Windows 的 `open`

那时：

```powershell
herdr plugin unlink plannotator-tui
# config.toml：prefix+o / Ctrl-click 改绑 annotate.open / annotate.open-link
# prefix+shift+o 先留着本仓库 last.ps1，直到上游 last 认 grok.exe / cursor-agent.cmd / agent
```

值得给上游提、但本仓库**没提**的（有空再开）：

- `herdr-annotate`：Windows 下载官方 TUI、用非 bash 启动 pane。
- `plannotator-tui`：`known_host` / `detect_host` 去掉 `.exe`/`.cmd`；Grok 读 `~\.grok\sessions`；Cursor Agent CLI 读 `~\.cursor\projects\...\agent-transcripts`。

---

## 卸载（如需）

```powershell
herdr plugin unlink plannotator-tui
herdr plugin action invoke unconfigure --plugin annotate   # 若曾跑过 configure；当前 annotate 插件无此项
herdr plugin uninstall annotate
plannotator uninstall --yes
Remove-Item "$env:LOCALAPPDATA\plannotator\plannotator-tui.exe" -ErrorAction SilentlyContinue
```

`plannotator uninstall --purge` 会删本地计划/历史，确认后再用。
