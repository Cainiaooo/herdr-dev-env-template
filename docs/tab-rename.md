# Tab auto-rename（Windows）

本机 tab 命名层。目标对应 [功能对照.md](../功能对照.md) §8：Herdr 内部 tab 不再长期停在 `1` / `2` / `3`，而是跟着 **当前主导 agent pane 已经写到终端标题里的那串字**。

Herdr 会捕获 pane 里的 OSC 0/2（`terminal_title_stripped`），**不会**自动把它写到自己的 tab 栏。插件做的就是这一跳。不另开模型起名，不读 Grok/Codex 的 session 文件。

---

## 选型

| 方案 | 结论 |
|---|---|
| [danbuhler/herdr-pane-topic-sync](https://github.com/danbuhler/herdr-pane-topic-sync) | **主力。** Windows + Bun；把 `terminal_title_stripped` 同步到 pane 标签和 tab 名。本机 `tab_source = "active"`：一个 tab 里多个终端时，用**该 tab 内最后焦点的 agent pane**。 |
| [iurysza/herdr-tab-smart-rename](https://github.com/iurysza/herdr-tab-smart-rename) | **不装。** 另开 OpenAI 兼容模型起名，默认不是本机 SpaceXAI/Grok；也不读 Grok/Agy 的 session 文件。 |
| [ryanlewis/herdr-tab-renamer](https://github.com/ryanlewis/herdr-tab-renamer) | **不装。** 同样吃 OSC，但 `platforms` 只有 macos/linux。 |
| [itayo-m/herdr-tab-session-name-sync](https://github.com/itayo-m/herdr-tab-session-name-sync) | **不装。** Windows 可用，默认只管 Copilot / OpenCode。 |
| [jovylle/herdr-session-title-name](https://github.com/jovylle/herdr-session-title-name) | **不装。** 清单写了 Windows，命令是 `sh`，原生 PowerShell 跑不起来。 |

**只装一套 rename。** 两家都会调 `herdr tab rename`，会互相覆盖。

---

## 本机已落地（2026-08-29）

| 组件 | 版本 / 位置 |
|---|---|
| Herdr | 0.8.2 |
| Bun | 1.4.0（Herdr 插件跑 `bun sync-labels.js`；PATH 约定见 [notator.md](notator.md)） |
| 插件 | id `dan.pane-topic-sync` 0.2.1，`herdr plugin install danbuhler/herdr-pane-topic-sync --yes` |
| 配置 | `%APPDATA%\herdr\plugins\config\dan.pane-topic-sync\config.toml` |

没有快捷键。事件（focus / agent 状态变化 / pane 增删）会自己刷；需要立刻对齐时用 action。

---

## 安装（可复现）

需要已装好的 Herdr ≥ 0.8.0，且当前用户 PATH 上有 `bun`。

```powershell
herdr plugin install danbuhler/herdr-pane-topic-sync --yes
```

校验：

```powershell
herdr plugin list --plugin dan.pane-topic-sync
# 应有 dan.pane-topic-sync (Pane Topic Sync) enabled
```

写入本机配置（目录安装时会建好，文件要自己放）：

`%APPDATA%\herdr\plugins\config\dan.pane-topic-sync\config.toml`

```toml
sync_panes = true
sync_tabs = true
respect_manual_names = true
tab_source = "active"
max_label_length = 60
tab_format = "{topic}"
pane_format = "{topic}"
```

和上游默认的差别只有 `tab_source`：上游是 `"first"`（左上角 pane），本机是 `"active"`（该 tab 内焦点 pane）。

立刻刷一轮（不 reload 也能跑；事件从下一拍开始接）：

```powershell
herdr plugin action invoke sync --plugin dan.pane-topic-sync
herdr plugin log list --plugin dan.pane-topic-sync --limit 5
```

stdout 类似：`synced: N pane rename(s), M tab rename(s), kept … manual name(s)`。`status` 应为 `succeeded`。

---

## 名字从哪来

`{topic}` = 该 agent pane 的 `terminal_title_stripped`。CLI 自己用 OSC 写什么，tab 就跟什么。插件**不**加 responding / waiting，也**不**读 `~/.grok/sessions/.../summary.json`。

| Agent | 本机实际看到的 OSC | tab 会变成 |
|---|---|---|
| Grok | `{activity} - {session 摘要} - grok`，干活时会带 spinner / `Waiting for response…` | 原样同步。状态字是 Grok 的 `[ui.notifications.title]`，本机不改这项。 |
| Codex | 常见是项目目录名（`NeonGame`、`herdr-perforce`） | 比数字好读，但不是任务级 session 名。 |
| 无 agent 的 shell / Sidebar / Perforce pane | 插件忽略 | tab 若整页都没有 agent，保持默认数字。 |

一个 tab 永远只有一个名字。多 pane 时：该 tab 内最后焦点的 **agent** pane 赢；焦点落在 Sidebar 等非 agent 上，则退回该 tab 里第一个有标题的 agent。

手工改过的 pane / tab 不再动。交还：

```powershell
herdr pane rename <pane_id> --clear
herdr tab rename <tab_id> 2    # 改回它当前的 tab number（不是随便一个数字）
```

Herdr 新建 tab 若弹出命名框并填了字，也算手工名。想继续自动命名，保持默认数字。

---

## 排障

```powershell
herdr pane list          # 看 agent、terminal_title_stripped、label
herdr tab list           # 看 tab label 是否已不是纯数字
herdr plugin log list --plugin dan.pane-topic-sync --limit 10
```

`program not found`：Herdr server 启动时 PATH 没有 `bun`。处理同 [notator.md](notator.md)（重开 Herdr，或临时 `bun.cmd` 垫片）。

Grok tab 跟着实时状态抖：预期行为。要冻成 session 名得另接 `summary.json`，本环境不做。
