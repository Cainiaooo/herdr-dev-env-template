# Herdr 快捷键（Windows）

本机自定义键写在 `%APPDATA%\herdr\config.toml`。官方默认见 `herdr --default-config` 和 [Keyboard](https://herdr.dev/docs/keyboard/)。

Herdr 0.8.2 **没有运行时改键界面**。`prefix+s` 设置页只有 theme / indicators / sound / toasts / integrations。`prefix+?` 是只读帮助（`/` 可过滤）。改键只能改 `config.toml` 再 reload。

---

## 本机已绑

前缀默认 `ctrl+b`。先按并松开前缀，再按动作键。

| 键 | 动作 |
|---|---|
| `Ctrl+B` `←` | 上一个 Agent（sidebar 顺序，循环） |
| `Ctrl+B` `→` | 下一个 Agent |
| `Ctrl+B` `↑` | herdr-plus Projects |
| `Ctrl+B` `↓` | herdr-plus Quick Actions |
| `Ctrl+B` `A` | 圈选终端文字批注 |
| `Ctrl+B` `Shift+A` | 复制批注为 Agent 上下文 |
| `Ctrl+B` `M` | 管理批注 |
| `Ctrl+B` `O` | plannotator-tui 审当前 pane 目录 |
| `Ctrl+B` `Shift+O` | plannotator-tui 审 focused Agent 最近回复 |
| `Ctrl+B` `Shift+B` | 开关 herdr-sidebar 插件 |

Agent 循环跟 `[ui] agent_panel_sort`。本机是 `"priority"`（attention 队列），不是按 workspace 分组。

插件键的细节仍在 [notator.md](notator.md) / [herdr-plus.md](herdr-plus.md)。

---

## 左右箭头占用

| 模式 | `←` / `→` | 能否改成切 Agent |
|---|---|---|
| Terminal（默认，键进 pane） | 给 Grok / vim / shell，Herdr 不抢 | **不要**绑裸 `left`/`right`，会吃掉光标 |
| Prefix（`ctrl+b` 后等一键） | 本机之前空着 | **已绑** `previous_agent` / `next_agent` |
| Navigate（`prefix+w` 工作区导航） | 硬编码切左右 pane，卸不掉 | 否 |
| Resize（`prefix+r`） | 硬编码左右拉 pane，和 `h`/`l` 一样 | 否 |

`prefix+h` / `prefix+l` 仍是切 pane，没动。

方向键若被外层终端吃掉（Windows Terminal 偶发），`prefix+↑`/`↓` 也会一起失效。那时换不带方向键的 chord，例如 `prefix+,` / `prefix+.`。

---

## 怎么改、怎么生效

没有「按一下就重绑」的 UI。步骤：

1. 编辑 `%APPDATA%\herdr\config.toml` 的 `[keys]` 或 `[[keys.command]]`。
2. `herdr config check` 看语法。
3. 热加载（不必重启 pane）：

```powershell
herdr server reload-config
```

TUI 里也可以 `prefix+shift+r`，或全局菜单 → `reload config`。

无效绑定 Herdr 会丢掉并保留旧 keymap，其它合法项仍会应用。`prefix+?` 里搜 `agent` 确认当前生效的是哪一键。

TOML：`[keys]` 标量必须写在 `[[keys.command]]` 之前。

切 Agent 用官方动作，不要再装 `choplin/herdr-next-agent`（那个插件默认只走 `blocked`）：

```toml
[keys]
previous_agent = "prefix+left"
next_agent = "prefix+right"
```
