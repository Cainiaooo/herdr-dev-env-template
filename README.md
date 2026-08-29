# herdr-dev-env-template

Windows 上 Herdr 开发环境的**配置说明和初始化指引**，不是 Herdr 本身，也不是业务代码。

对着这份仓库在新机器上复现：终端工作区、代理、批注层、tab 自动命名、以及后续要补的 P4 / Git 宿主。对照表是需求；`docs/` 里是已经落地的装法和用法。

## 文档

| 文档 | 内容 |
|---|---|
| [功能对照.md](功能对照.md) | 目标功能 vs 社区方案 vs 本机处理。Windows 约束写在这里。 |
| [docs/notator.md](docs/notator.md) | **Notator 已落地配置：** Plannotator（Chrome）+ herdr-annotate（圈终端字）+ plannotator-tui（Herdr 里审 Markdown），安装、快捷键、如何把批注送回 Agent Session。 |
| [docs/tab-rename.md](docs/tab-rename.md) | **Tab auto-rename 已落地配置：** pane-topic-sync 把 agent 的 OSC 终端标题同步到 Herdr tab；多 pane 跟焦点；手工名不覆盖。 |
| [docs/pi-websearch.md](docs/pi-websearch.md) | **Pi 网页搜索：** 为何装 `pi-web-access`、零配置实际走 Exa MCP、和 Claude Code WebSearch 的差别。 |

## 本机前提（概要）

- Windows 11 x64
- Herdr 0.8.2（`irm https://herdr.dev/install.ps1 | iex`）
- PowerShell 7、Git、Chrome
- 代理：Clash Verge mixed `127.0.0.1:7897`（见功能对照 §2）
- Perforce 工作流另需 `p4` 和有效 client

Notator 的逐步安装见 [docs/notator.md](docs/notator.md)，不要从功能对照里的「处理」栏直接抄过期方案（例如移植 herdr-reviewr）。Tab 自动命名见 [docs/tab-rename.md](docs/tab-rename.md)，不要叠装第二套 rename 插件。

## 仓库约定

- 只放指引和本环境相关的配置摘录，不放密钥、不放 `p4` client spec、不放 `%APPDATA%\herdr` 整棵树。
- 新机器按文档安装；把本仓库当作 checklist，而不是安装器。
