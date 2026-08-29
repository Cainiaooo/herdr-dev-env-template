# Notator（Windows）

本机批注层。目标对应 [功能对照.md](../功能对照.md) §6：在 diff / 文档 / 终端文本上标注，并把反馈送回**当前那条 Agent 对话**。

Windows 上不走 Herdr 内嵌浏览器。审代码和文档用系统 Chrome 里的 **Plannotator**；在 Herdr pane 里圈终端文字用 **herdr-annotate**。

---

## 选型

| 方案 | 结论 |
|---|---|
| [herdr-plannotator](https://github.com/plannotator/herdr-plannotator) + [herdr-browser](https://github.com/ogulcancelik/herdr-browser) / [terminal-browser](https://github.com/zenbu-labs/terminal-browser) | **不装。** 清单只有 linux/macos，依赖 Kitty graphics。Windows Terminal 走不通；官方只测过 WezTerm + WSL。 |
| [herdr-reviewr](https://github.com/persiyanov/herdr-reviewr) | **不装。** 无 Windows，且绑 Git worktree，P4 workspace 不能 fork 它。 |
| [Plannotator OSS](https://docs.plannotator.ai/open-source/) | **主力。** Windows 官方安装器；`plannotator review` 认 Git 和 Perforce。 |
| [herdr-annotate](https://github.com/plannotator/herdr-annotate) | **附件。** 终端选中文本；Windows 为 preview。文档审阅用的 `plannotator-tui` 仍是 macOS/Linux。 |

批注回到 Agent 的方式：**谁启动 `plannotator` 并阻塞等 stdout，谁就是会话。** 不是 Herdr pane ID，也不是「系统里随便开一次 review」。自己在空终端跑 `plannotator review`，没有任何 Agent 会收到结果。

---

## 本机已落地（2026-08-29）

| 组件 | 版本 / 位置 |
|---|---|
| Herdr | 0.8.2，`%LOCALAPPDATA%\Programs\Herdr\bin\herdr.exe` |
| Plannotator | 0.27.9，`%LOCALAPPDATA%\plannotator\plannotator.exe` |
| Bun | 1.4.0（winget `Oven-sh.Bun`） |
| herdr-annotate | 插件 id `annotate` 0.3.0，`herdr plugin install plannotator/herdr-annotate` |
| Perforce CLI | 已有 `p4`；本机 client `xucongwei_development`，root `E:\Project` |
| 系统浏览器 | Chrome 151 |

Skill 装在：

- `%USERPROFILE%\.agents\skills\`（Grok / Codex 等共用）：`plannotator-review`、`plannotator-annotate`、`plannotator-last`
- `%USERPROFILE%\.claude\skills\`：同上三份

三份 skill 均 `disable-model-invocation: true`：**人来点，模型不要自己弹浏览器。**

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

Windows 会跳过 `bash scripts/fetch-plannotator-tui.sh`。可用动作只有 `capture` / `copy-context` / `manage`。`open` / `last` / `open-link` 是 macos/linux。

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

---

## 日常怎么用

### 把批注送回某个 Agent Session

在**那条正在干活的 Agent 对话**里让它开 Plannotator，不要另开终端自己跑。

Grok 示例：

- `/plannotator-review` 或「用 Plannotator 审一下当前改动」
- `/plannotator-annotate plan.md`
- `/plannotator-last`（审刚说的那段）

Agent 执行对应命令并阻塞。Chrome 打开后你点 **Send Feedback** 或 **Approve**。进程退出，stdout 回到**同一次**工具调用，Agent 按批注继续。不要把浏览器内容复制进聊天。

cwd 必须对：P4 审阅在 client view 里开（本机是 `E:\Project`）。在 Git 仓库目录跑会走 Git，不会走 Perforce。

自己在终端跑 `plannotator review` 也可以看 diff，但没有 Agent 在等 stdout。要把结果给 Session，只能粘贴终端输出，或关掉这次、让 Agent 重新开。

### Herdr 快捷键（终端文字）

| 键 | 动作 |
|---|---|
| `Ctrl+B` `A` | 给当前选中文字写备注 |
| `Ctrl+B` `Shift+A` | 复制全部备注为给 Agent 的 Markdown |
| `Ctrl+B` `M` | 管理备注 |

这和 Plannotator 网页审阅是两条线：前者贴到 focused pane / 剪贴板，后者走启动它的那次 CLI stdout。

### Perforce

`plannotator review` 在 Git 判定之后跑 `p4 info`，认当前 client root。默认看 default changelist 里打开的文本文件；二进制 opened 会跳过；没有 staging UI。编号 pending CL 在页面的 comparison 里选。

P4 的树 / Diff / Submit 仍归 `herdr-perforce`，Plannotator 不替代它。

---

## 刻意没做的

- **没把 skill 改成模型可调用。** 需要 Agent 改完自动弹审阅时，再跑安装器 `-Reconfigure`，或 `-ModelInvocable plannotator-review`。
- **没装 Claude Code marketplace 插件。** 本机 `claude` 是损坏的 `claude-cac` 包装。`~\.claude\skills\` 已有文件；Claude 本体修好后在里面执行：
  ```
  /plugin marketplace add backnotprop/plannotator
  /plugin install plannotator@plannotator
  ```
  这才会接上 `ExitPlanMode` 自动计划闸门。
- **没改 Codex hook。** Windows 上官方仍标实验，安装器只打印了手动步骤。
- **没装 herdr-plannotator。** 内嵌 Browser pane 这条链路 Windows 不可用。

---

## 卸载（如需）

```powershell
herdr plugin action invoke unconfigure --plugin annotate   # 若曾跑过 configure；当前 annotate 插件无此项
herdr plugin uninstall annotate
plannotator uninstall --yes
```

`plannotator uninstall --purge` 会删本地计划/历史，确认后再用。
