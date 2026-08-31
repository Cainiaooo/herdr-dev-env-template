# herdr-plus（Windows）

本机指令缓存和工作区模板层。目标对应 [功能对照.md](../功能对照.md) §4：全局 + 工程两层保存常用命令，快捷键唤出列表后一键跑。顺带用同一插件的 **Projects** 从一份 TOML 起整套 workspace。

上游：[cloudmanic/herdr-plus](https://github.com/cloudmanic/herdr-plus) / [herdrplus.com/docs](https://herdrplus.com/docs/)。本页只记本机装法、Windows 差值和已经接上的 DevDocs 命令。

---

## 选型

| 方案 | 结论 |
|---|---|
| [herdr-plus](https://github.com/cloudmanic/herdr-plus) Quick Actions | **主力。** 全局 `quick-actions/` + 工程 `.herdr-plus/quick-actions/`；Windows 能装，安装要本机 Go。 |
| [leonho/herdr-cmd-marks](https://github.com/leonho/herdr-cmd-marks) | **不装。** 产品更像「收藏命令 + ctrl-o 新 pane」，但 `platforms` 只有 macos/linux。 |
| [vjeantet/herdr-palette](https://github.com/vjeantet/herdr-palette) 自定义命令 | **不装。** 选中会新开 pane，但只有全局 argv、无 shell、无 Windows。 |
| [speardragon/herdr-command-center](https://github.com/speardragon/herdr-command-center) | **不装。** `type=pane` 是打进当前 pane，Agent 占着会误送。无 Windows。 |
| 原生 `[[keys.command]]` `type = "pane"` | 少量固定快捷键可以，没有命令库。 |

command palette 类插件搜的是已有 Herdr action，不是存 Shell 命令。

---

## 本机已落地（2026-08-29）

| 组件 | 版本 / 位置 |
|---|---|
| Herdr | 0.8.2 |
| Go | 1.27.0，`D:\DevelopmentEnvironment\go`（用户 PATH：`D:\DevelopmentEnvironment\go\bin`） |
| 插件 | id `cloudmanic.herdr-plus` 0.1.24，`herdr plugin install cloudmanic/herdr-plus --yes` |
| 配置 | `%APPDATA%\herdr\plugins\config\cloudmanic.herdr-plus\` |
| 快捷键 | `prefix+up` Projects；`prefix+down` Quick Actions（Windows action id 带 `-windows`） |

GOPATH / 模块缓存仍是默认 `C:\Users\Admin\go`。工具链在 D:，不把整个 Go 工作区搬过去。

---

## 安装（可复现）

Windows 上 `herdr plugin install` 的 build 是 `go build -o bin/herdr-plus.exe .`，**没有** Linux/macOS 那种预编译回退，所以 PATH 上必须有 `go`。

### 1. Go

官方 zip 解到自定义目录（不要用 winget 默认装到 `C:\Program Files\Go`，除非就是想装那儿）：

```powershell
# 例：go1.27.0 windows-amd64，SHA256 以 https://go.dev/dl/ 为准
$dest = 'D:\DevelopmentEnvironment'
$zip  = Join-Path $env:TEMP 'go1.27.0.windows-amd64.zip'
curl.exe -fsSL --proxy 'http://127.0.0.1:7897' -o $zip 'https://go.dev/dl/go1.27.0.windows-amd64.zip'
Expand-Archive $zip $dest
$bin = Join-Path $dest 'go\bin'
$user = [Environment]::GetEnvironmentVariable('Path', 'User')
[Environment]::SetEnvironmentVariable('Path', "$bin;$user", 'User')
$env:Path = "$bin;$env:Path"
go version   # go version go1.27.0 windows/amd64
```

已经在跑的 Herdr 服务进程**不会**自动看见新 PATH。插件编好之后不必为 herdr-plus 本身重启；要在 pane 里直接敲 `go`，重启一次 Herdr。

### 2. 插件

```powershell
herdr plugin install cloudmanic/herdr-plus --yes
herdr plugin list --plugin cloudmanic.herdr-plus
herdr plugin action invoke ping-windows --plugin cloudmanic.herdr-plus
herdr plugin log list --plugin cloudmanic.herdr-plus --limit 3
# stdout 应有：herdr-plus ping ok
```

### 3. 快捷键

Windows 的 action id 是 `*-windows` 后缀。绑官方文档里的 `cloudmanic.herdr-plus.quick-actions` 在这台机器上不会跑。写入 `%APPDATA%\herdr\config.toml`：

```toml
[[keys.command]]
key = "prefix+up"
type = "plugin_action"
command = "cloudmanic.herdr-plus.projects-windows"
description = "herdr-plus: projects"

[[keys.command]]
key = "prefix+down"
type = "plugin_action"
command = "cloudmanic.herdr-plus.quick-actions-windows"
description = "herdr-plus: quick actions"
```

```powershell
herdr server reload-config
```

`ctrl+b` 然后 `↑` / `↓`。方向键被终端吃掉就换不带方向键的 chord。

---

## 插件本身有什么

三块，全是「一个 TOML 文件一条」。加文件即加条目，删文件即删。配置根：

```
%APPDATA%\herdr\plugins\config\cloudmanic.herdr-plus\
  projects\          # 空着显示 onboarding，不种示例
  quick-actions\     # 第一次打开 launcher 才种示例；之后删了不会再出现
  worktrees\         # 不自动创建；有文件才在 worktree.created / opened 时铺 tab
```

查路径：`herdr plugin config-dir cloudmanic.herdr-plus`。

### Quick Actions

`prefix+↓` 在当前 workspace 上开 overlay。输入过滤，Enter 跑，Esc 取消。命令在**按下快捷键时那个 pane 的 cwd**里走 PowerShell，然后 overlay 关掉。

| 层 | 位置 | 何时出现 |
|---|---|---|
| Global | 插件 config 的 `quick-actions/*.toml` | 任何地方 |
| Project | `<工程根>/.herdr-plus/quick-actions/*.toml` | **仅当 focused pane cwd 正好是这个工程根** |

herdr-plus **不会**从子目录往上找 `.herdr-plus`。Agent pane 若 `cd` 进了 `Source\...`，Project 那组不会出现。

类型：`command`（立刻跑）、`select`（再选一项）、`form`（填一个值）。命令是 Go template，`{{.WorkDir}}` / `{{.Value}}` / `{{opener}}`（Windows 上是 `Start-Process`），同时有 `HERDR_PLUS_*` 环境变量。

默认执行模型是 overlay 里跑完即关。输出快会看不见。本机 toast（`[ui.toast] delivery`）默认 `off`，`herdr notification show` 也不出。需要盯结果的命令不要指望 overlay。Toast 本身是 Herdr 功能，记录在 [toast.md](toast.md)；不要为了看 Quick Action 输出去开。

### Projects

`prefix+↑` 模糊选一个模板，按 TOML 建 workspace：tab 顺序、每 tab 一条启动命令或最多 4 个 pane（`split = "down"|"right"`，可 `ratio`）、`working_dir` 可按 tab/pane 覆盖。`group` 只影响列表分组。

无 UI 打开（要把 `herdr-plus.exe` 放到 PATH，或写插件目录里那份的绝对路径）：

```powershell
herdr-plus open <project-name>
```

### Worktree 自动布局

不按键。Herdr 创建或打开 git worktree 时，按 `worktrees/*.toml` 的 `repo`（可选 `branch`）把和 Projects 一样的 tab 布局填进新 workspace。没有这个目录就是空操作。本机 P4 工作流用得少，文件先不必建。

---

## 本机已接的 DevDocs 命令

日常提交 / 全机拉取走 `ndocs`（canonical：`D:\Projects\xuxu-dev-docs`）。语义、`-Apply` / `-Push`、dirty 跳过，以 [xuxu-dev-docs README](D:\Projects\xuxu-dev-docs\README.md) 为准。Herdr 只是唤起方式。

因为 overlay 关了就看不到 `ndocs` 输出，这两条**不**在 overlay 里跑：wrapper 对**发起快捷键的那个 pane**做 `herdr pane split --direction down`，在新 pane 里执行，结尾打 `OK` / `FAILED`，Enter 关 pane。

| 动作 | 范围 | 实际命令 |
|---|---|---|
| **DevDocs: Publish** | 三个 NeonGame 工程根的 Project 组 | `ndocs publish -Message <表单> -Push -Apply` |
| **DevDocs: Sync all** | 全局 | `ndocs sync-all -Apply` |

空 message → `docs: publish NeonGame DevDocs`。

文件：

| 路径 | 作用 |
|---|---|
| `E:\Project\NeonGame\.herdr-plus\quick-actions\devdocs-publish.toml` | `xucongwei_development` |
| `G:\Projects\Neon\NeonGame\.herdr-plus\quick-actions\devdocs-publish.toml` | `xucongwei_CE_Dev` |
| `G:\Projects\NeonPerf\NeonGame\.herdr-plus\quick-actions\devdocs-publish.toml` | 尚未 overlay bootstrap，点了会失败 |
| `%APPDATA%\herdr\plugins\config\cloudmanic.herdr-plus\quick-actions\devdocs-sync-all.toml` | 全局 Sync all |
| `%APPDATA%\herdr\plugins\config\cloudmanic.herdr-plus\scripts\invoke-ndocs.ps1` | split + 跑 + 结果横幅 |

`.herdr-plus/` 是本机 Herdr 配置，**不要** `p4 reconcile` / `p4 add` 进 depot，也不进 overlay Git。`.p4ignore.personal` 由 ndocs 按 Git index 生成，不要手改来忽略这个目录。

用法：焦点 pane cwd = 该 NeonGame 根 → `ctrl+b` `↓` → 选动作。Sync all 不要求在某个 NeonGame 里。

本机 overlay 目前只有：

- `xucongwei_development` → `E:\Project\NeonGame`
- `xucongwei_CE_Dev` → `G:\Projects\Neon\NeonGame`

NeonPerf 要先：

```powershell
pwsh D:\Projects\xuxu-dev-docs\.personal-dev\scripts\ndocs.ps1 bootstrap -ProjectRoot G:\Projects\NeonPerf\NeonGame -Apply
```

之后 Sync all 才会带上它。

---

## 校验

```powershell
go version
herdr plugin list --plugin cloudmanic.herdr-plus
herdr plugin action list --plugin cloudmanic.herdr-plus
# Windows 应有 projects-windows / quick-actions-windows / ping-windows
Test-Path (Join-Path $env:APPDATA 'herdr\plugins\config\cloudmanic.herdr-plus\scripts\invoke-ndocs.ps1')
Test-Path 'E:\Project\NeonGame\.herdr-plus\quick-actions\devdocs-publish.toml'
```

在 Herdr 里 `prefix+↓` 应能看到 Global 的 **DevDocs: Sync all**；在上述工程根还应看到 Project 的 **DevDocs: Publish**。

---

## 不要做

- 不要绑非 `-windows` 的 action id。
- 不要叠装 cmd-marks / command-center / 第二个「保存命令」插件。
- 不要为了看结果去开 `[ui.toast]`：默认 `off` 是为了少被 Agent 状态弹窗吵；DevDocs 走 split pane。
- 不要把 `.herdr-plus` 当 P4 或 overlay 的一部分维护。
