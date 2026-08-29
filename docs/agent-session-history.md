# Workspace 过往 Agent Session（Windows）— 暂不落地

目标对应 [功能对照.md](../功能对照.md) §9：在终端里快速列出 **当前 Herdr workspace（项目 cwd）** 跑过哪些 Agent Session，能翻对话、必要时 resume。

**结论（2026-08-29）：暂停 Herdr 插件。** 社区有几家在做 inbox / 归档搜索 / 跨环境挖掘，功能对得上，但没有 Windows 面；inbox / omnisearch 还不读 Grok。Herdr 本体没有对话浏览器。本机先用 Grok 自带的 `/resume` 和 `grok sessions list`。未装任何相关插件。

---

## 要的是什么

- 按 **这个 workspace 的 cwd** 看过往 Agent 对话，不是 Herdr 侧栏里现在还开着的 pane。
- 终端里能列、能搜、能点回去（resume 或只读翻记录）。
- 本环境主力是 Grok（session 在 `~\.grok\sessions\<cwd-slug>\<session-id>\`）；Agy 是次要。Claude / Codex 不是本机默认。

不是：

- Herdr workspace / tab / pane 树（官方 `prefix+g`）。
- 服务器重启后续上 **当时那个** agent pane（`[session] resume_agents_on_restore`）。
- Tab 跟着 OSC 标题改名（§8 pane-topic-sync，不读 session 文件）。

---

## 选型

| 方案 | 形态 | Windows | 读 Grok | 结论 |
|---|---|---|---|---|
| [douglascorrea/herdr-agent-inbox](https://github.com/douglascorrea/herdr-agent-inbox) | `prefix+i` popup；`h` 全局 history；已关闭会话挂在 workspace/目录下；有 session ref 则 `claude --resume` / `pi --session` / `codex resume` | 无（`linux`/`macos`，startup `/bin/sh`） | 否，只读 Claude / Pi / Codex transcript | **不装。** 最像「按 workspace 列历史」，但对本机 Agent 盲。 |
| [dmnkf/herdr-omnisearch](https://github.com/dmnkf/herdr-omnisearch) | `prefix+o` 活 pane；`prefix+shift+o` 归档对话全文搜索；可 resume | 无 | 默认配置只有 Codex + Claude glob，Grok 要自己加 | **不装。** |
| [taxueseek/session-digger](https://github.com/taxueseek/session-digger) | `sd-sessions` / `sd-search` / `sd-fuzzy-search`；FTS 索引；支持 Grok `chat_history.jsonl` + `events.jsonl` | 无（清单 linux/macos，动作 `bash`） | 是 | **不装。** 能力最贴；没有 PowerShell 启动面。 |
| [connerohnesorge/herdr-vaultr](https://github.com/connerohnesorge/herdr-vaultr) | 当前 pane 的 vault transcript / 搜索 / fork | 无 | 绑 Claude / Codex / Pi + vaultr | 不是按 workspace 列历史。 |
| [wilbeibi/herdr-catchup](https://github.com/wilbeibi/herdr-catchup) | 当前 pane 会话摘要 / fork / 交给别的 agent | 无 | 列表含 Antigravity，不是浏览器 | 交接，不是历史列表。 |
| [iviaxpow3r/herdr-session-parker](https://github.com/iviaxpow3r/herdr-session-parker) | 记下 cwd + session id，关掉 pane，以后 resume | 无 | 靠 Herdr integration 报的 session ref | 停车，不是翻旧对话。 |
| [fullerzz/herdr-plugin-sesh](https://github.com/fullerzz/herdr-plugin-sesh) | Sesh 式 workspace picker | — | — | session = Herdr workspace。 |
| [ismaelosuna7824/herdr-recent-workspaces](https://github.com/ismaelosuna7824/herdr-recent-workspaces) | 最近打开过的文件夹 | — | — | 同上。 |
| [0x5c0f/herdr-insight](https://github.com/0x5c0f/herdr-insight) | Agent working/blocked 时间线 | 无 | 状态，不是对话 | 不装。 |
| [jugyo/herdr-nav-history](https://github.com/jugyo/herdr-nav-history) | pane 焦点前进后退 | — | — | 不装。 |
| 官方 | `prefix+g` 树；`resume_agents_on_restore` | 有 | 只 resume 当时报过 session ref 的 pane | 没有过往对话列表。 |
| Grok CLI | `/resume`、欢迎屏、`grok sessions list` / `search` | 有 | 按 cwd 分组，本机权威存储 | **现行办法。** |

不要叠装 inbox + omnisearch + session-digger。不要为了 tab 名去读 `summary.json`（§8 明确不做）。

---

## 本机现行（不是插件）

Grok 把每个对话存在 `~\.grok\sessions\<encoded-cwd>\<session-id>\`，`summary.json` 是标题/摘要，`updates.jsonl` 是 resume 用的对话日志。列表面天然按 **当前工作目录** 过滤，和 Herdr workspace cwd 对齐。

Grok TUI：

```text
/resume
```

列当前 workspace 近期 session；输入按标题过滤，也会搜对话内容。欢迎屏同样列当前目录最近会话。

终端（cwd 必须是那个 workspace）：

```powershell
grok sessions list
grok sessions list --limit 50
grok sessions search "某个关键词"
grok --resume
```

`grok --resume` 不带参数续上这个目录最近一条。指定 id 或标题：`grok --resume <session-id-or-title>`。

Herdr 重启后续上 **当时还开着的** Grok pane，靠 `herdr integration install grok` + `grok --resume <id>`，解决的是「pane 别丢」，不是「把这个项目以前所有 session 列出来」。

---

## 以后若要做成 Herdr 弹层

优先序：

1. **不要**硬装 inbox / omnisearch：无 Windows，且默认不读 `~\.grok\sessions`。
2. 若只服务本机 Grok：薄插件调 `grok sessions list` / 打开 `/resume`，比移植 Unix TUI 便宜。
3. 若要跨 Grok + Agy + 以后别的 CLI：fork [session-digger](https://github.com/taxueseek/session-digger)，补 `platforms = ["windows"]` 和 PowerShell 动作；它已经认 Grok jsonl。不要从 inbox 改起。

未再启动前先读这一页，不要默认 `herdr plugin install douglascorrea/herdr-agent-inbox`。
