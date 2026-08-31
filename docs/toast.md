# Herdr toast / notification（Windows）

Herdr 自己的弹出提示，不是 Windows 系统通知中心里随便一个气泡。Agent 在**后台 tab** 跑完或等你输入时会用它；插件也可以用 CLI 主动弹一条。

本机 **现在是关的**（`[ui.toast] delivery = "off"`，也是官方默认）。`herdr notification show` 会返回 `shown: false, reason: disabled`。plannotator-tui 垫片的残留批注警告因此改走 Windows 对话框；toast 打开之后同一条会改走 in-app toast，不再叠对话框。

**后续把开发环境「输入化 / 固化配置」时再打开**，不要为了看 herdr-plus overlay 里那一行命令输出去开（见 [herdr-plus.md](herdr-plus.md)）。打开的目的是：后台 Agent 状态、插件主动提示（残留批注、pane 不可用等）。

---

## 它做什么

| 来源 | 不打开 toast 时 | `delivery = "herdr"` 时 |
|---|---|---|
| 后台 workspace 里 Agent 结束 / 要你输入 | 没弹出；sidebar 状态点仍在 | 角上一条 in-app toast；可配延迟和声音 |
| `herdr notification show`（插件 / 脚本） | JSON `shown: false` | 同样一条 toast |
| 复制到剪贴板的反馈 | `[ui.toast.clipboard]`，和上面的 delivery 是分开的开关 | 剪贴板 toast 默认开 |

当前 tab 里正在看的 Agent，Herdr **不会**再弹 toast（官方：suppress popups for the active tab）。所以它主要服务「你在看 A，B 跑完了」。

---

## 配置

`%APPDATA%\herdr\config.toml`。改完 `herdr server reload-config`（大多数 UI 项不用重启 pane）。

```toml
[ui.toast]
# off     = 不弹（本机现状 / 官方默认）
# herdr   = Herdr 窗口内 toast（后续推荐先试这个）
# terminal = 让外层终端弹桌面通知，SSH 远程也用这个
# system  = 走 OS 通知（Windows 通知中心；macOS 优先 terminal-notifier）
delivery = "off"
delay_seconds = 1

[ui.toast.herdr]
position = "bottom-right"   # top-left / top-right / bottom-left / bottom-right

[ui.toast.clipboard]
enabled = true
position = "bottom-center"
```

声音是另一块，和 toast 能否显示无关：

```toml
[ui.sound]
enabled = true
# path / done_path / request_path = 自定义 mp3（相对 config.toml 所在目录）

# [ui.sound.agents]
# droid = "off"    # 官方默认静音 droid
```

`HERDR_DISABLE_SOUND=1` 可以临时关掉声音。

首次启动还有 notification onboarding（`onboarding = true`）；本机装好后应已是 `false`。

---

## CLI（插件用这个）

```powershell
herdr notification show "Title" --body "details" --position bottom-right --sound request
```

| 参数 | 值 |
|---|---|
| 标题 | 必填位置参数 |
| `--body` | 正文 |
| `--position` | `top-left` / `top-right` / `bottom-left` / `bottom-right` |
| `--sound` | `none` / `done` / `request` |

成功但被关掉时 stdout 类似：`{"shown":false,"reason":"disabled"}`。垫片靠 `shown: true` 决定还要不要 MessageBox。

本机已经在用的调用：

- `plugins/plannotator-tui`：TUI exe 缺失；`prefix+o` 打开目录时仓库里还有残留批注（toast 关则对话框）
- 官方 `herdr-annotate`：review pane 拉不起来
- `herdr-sidebar`：关掉 sidebar 被取消时

---

## 快捷键冲突（打开 toast 前要改）

官方默认 `keys.open_notification_target = "prefix+o"`：从 toast **跳到发出这条通知的 pane**。

本机 `prefix+o` 已经绑成 `plannotator-tui.open`。输入化打开 toast 时，给 `open_notification_target` 另绑一键（例如 `prefix+shift+n`），不要和审 Markdown 抢。

---

## 输入化时建议做的

1. `delivery = "herdr"`，先不要上 `system`（Windows 通知中心另有一套权限/专注助手）。
2. `herdr server reload-config`，在后台 tab 让 Agent 跑完，确认角上能看到。
3. 改 `open_notification_target`，避免和 `prefix+o` 冲突。
4. 看一眼还有哪些插件适合 `notification show`：长时间 fetch、P4 submit 结果、herdr-plus 后台命令结束（现在 DevDocs 故意用 split pane，不要改回 toast 当日志窗）。
5. 残留批注警告会自动改走 toast；对话框仅在 `shown: false` 时出现。

还没查清、打开后再补的：

- toast 点一下是只 focus pane，还是带 payload
- `delay_seconds` 对插件 `show` 是否同样生效
- 多条 toast 的堆叠上限和是否可点进历史
