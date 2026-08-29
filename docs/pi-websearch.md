# Pi Web Search（Windows）

Pi 默认只有文件和 shell 工具，没有网页搜索。本机给 Pi 加搜索的方式：**装社区包 `pi-web-access`，不配 API key 也能搜。**

和 [功能对照.md](../功能对照.md) §2 的代理约定一起用：Herdr pane 里 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` 指向 Clash mixed `127.0.0.1:7897`。

本文只记录选型、零配置实际行为和安装。不放密钥。

---

## 选型（2026-08-29）

Pi 核心故意做小。官方不内置 MCP、WebSearch、子 agent、plan mode。内置工具：

`read` · `write` · `edit` · `bash` · `grep` · `find` · `ls`（Windows 另有可选 `powershell`）

社区加搜索的三条路：

| 路 | 做法 | 结论 |
|---|---|---|
| **Pi 包** | `pi install npm:某个包`，包里 `registerTool(web_search)` | **走这条。** 装 `pi-web-access`。 |
| MCP 适配器 | `pi-mcp-adapter` + Brave/Tavily 等 MCP server | 已有 Cursor/Claude 的 `mcp.json` 时再考虑。只为搜网页不必。 |
| 自己写 extension / skill | `pi.registerTool()` 或 CLI + `SKILL.md` | 少数人才走。 |

`pi-web-access`（[nicobailon/pi-web-access](https://github.com/nicobailon/pi-web-access)，gallery [pi.dev/packages/pi-web-access](https://pi.dev/packages/pi-web-access)）是这个品类的事实标准（约 39 万次/月下载，其余 web 包多在一两百）。零配置走 Exa 托管 MCP，不需要 key。

**不装这些（本机已选定 `pi-web-access`）：**

| 包 | 原因 |
|---|---|
| `@boti-ormandi/pi-web` | 复用 `/login` 过的 Codex / Claude / Grok OAuth。本机先走通用零配置。 |
| `pi-xai` / `pi-xai-oauth` | Grok Build 原生 `web_search` / `x_search`。那是 xAI 订阅专用，和「给任意模型加搜索」不是一回事。 |
| `pi-native-search` | 跟当前模型的原生 search；xAI 那条要 `XAI_API_KEY`，不是订阅 OAuth。 |
| `stnly/pi-grok`、`pi-xai-search` | 只有 `x_search`（搜 X），不是网页搜索。 |
| `@tavily/pi-extension` 等 | 要单独的搜索 API key。 |

**只装一个 web 包。** 多个包都会注册叫 `web_search` 的工具，会撞名。

xAI 订阅登录（`/login xai`）只解决模型和配额，**不会**自动给 `web_search`。要 Grok 原生搜索时再另议，不要和本包叠装。

---

## 零配置时实际怎么搜

没有 `~/.pi/web-search.json`、也没有搜索 API key：

```
模型调用 web_search({ query: "..." })
        │
        ├─ 当前模型是 openai-codex 且已 /login
        │     → 先试 Codex 的 OpenAI Hosted web_search
        │
        └─ 其他情况（含 xAI / 本机默认）
              → Exa 托管 MCP https://mcp.exa.ai/mcp
                 匿名、免 key、有速率限制
```

不是 DuckDuckGo，也不是 Google SERP。DuckDuckGo 在这个包里是 explicit-only，`auto` 不会选它。

Exa 是 **neural / semantic search**（`type: auto`）：查询更像「描述想找到的那类页面」，不是纯关键词。免 key 的 MCP 路径通常只吃 `query` + `numResults`；`recencyFilter` / `domainFilter` 要有 `EXA_API_KEY` 走 REST 才完整。

默认：

| 项 | 值 |
|---|---|
| 每条 query 结果数 | 5（上限 20） |
| `includeContent` | 关（不把整页塞进主对话） |
| `workflow` | `summary-review`（打开 curator） |
| 默认域名白名单 | **没有** |
| 默认时间窗 | **没有** |
| 默认多引擎交叉 | **没有**（`provider: "all"` 要显式指定） |

### curator（默认开）

搜完会弹出结果卡片，可勾选、可改 query。用一个便宜模型写摘要草稿（优先 Claude Haiku → Codex Luna/Terra → Gemini Flash → GPT mini → DeepSeek Flash；当前 Pi 里没有这些就退回「标题 + 链接」列表）。**20 秒**没人操作就自动提交。

主模型拿到的是 **摘要 + 来源**，不是原始 SERP。这是相对 Claude Code `WebSearch` 多出来的整理层：主 context 更省，但多一轮延迟，摘要可能漏细节。

关掉：

```
/curator off
```

或单次：`web_search({ query: "...", workflow: "none" })`。

### 过滤：有能力，默认全关

工具 *支持*，但要模型在 tool call 里传，或以后配 key：

```js
web_search({
  query: "rust tokio spawn",
  numResults: 10,
  recencyFilter: "week",          // day | week | month | year
  domainFilter: ["docs.rs", "github.com", "-medium.com"],
  includeContent: true
})
```

不要指望装完就自动「只搜官方文档、只要最近一周、多源交叉」。零配置能搜、能给带来源的短摘要。范围过滤、时效、全面性靠模型写参数，或再配 Tavily / Brave / SearXNG。

写代码查库 / API / SDK，优先让它走 **`code_search`**（Exa code context），比泛 `web_search` 更接近精准。

### 和 Claude Code / Codex 自带 WebSearch 的差别

| | Claude Code `WebSearch` | Codex / Grok 原生 `web_search` | **pi-web-access 零配置** |
|---|---|---|---|
| 谁执行搜索 | Anthropic 服务端 | 模型厂商服务端 | 本机调 Exa MCP |
| 默认结果 | 标题 + 链接 + snippet | 搜和答绑在同一次推理，带 citation | 5 条 Exa 结果，再合成 summary |
| 默认域名 / 时间过滤 | 没有（可选 `allowed_domains`） | 一般没有 | **没有** |
| 搜完还干什么 | 结果直接给模型 | 搜和答一次完成 | **默认 curator + 摘要** |
| 用户能看见什么 | 一次 tool 调用 | 一次 tool / 内嵌 citation | curator 卡片、provider、Ctrl+Shift+W |

配套（官方 WebSearch 通常没有）：

- **`fetch_content`**：GitHub 是 clone 成本地再 `read`，不是刮 HTML；PDF / YouTube 有专门路径。
- **`get_search_content`**：整页缓存在 `web-search-cache`（1 小时、128 条 / 128 MiB），主对话默认约 3 万字符，细节再 `offset` / `findText`。
- **`source_check`**：对某个 claim 做带出处核对。
- **Ctrl+Shift+W**：看这次用了哪个 provider、状态码、耗时。这是过程，不是「搜索范围白名单」。

三个词分开看：

| 目标 | 零配置实际效果 |
|---|---|
| 更准 | 中等。Exa 语义检索对「找那类文档」比纯关键词好；摘要会丢原文。没有文档站默认白名单。 |
| 更省 token | 对主模型偏省（5 条 + summary）。对等待时间不省（curator 默认 20 秒）。Exa 免 key 有配额。 |
| 更全 | 默认不强。要更全：多次 query、`queries: [...]`，或以后配别的 provider。 |

---

## 安装

Pi 已能启动。在 **Pi 自己的会话**里装（不要和 `herdr plugin` 搞混）：

```powershell
pi install npm:pi-web-access
```

然后 `/reload`，或退出再进 `pi`。启动日志 `[Extensions]` 里应能看到它。

验证：直接说「搜一下 TypeScript 5 的发行说明」，应出现 `web_search` 调用。Ctrl+Shift+W 可看 Exa MCP 请求。

可选配置文件：`%USERPROFILE%\.pi\web-search.json`。零配置不必建。本机若走 Clash TUN / fake-IP，搜索失败再加：

```json
{
  "ssrf": {
    "trustEnvProxy": true
  }
}
```

本机 mixed 端口是 `127.0.0.1:7897`。`ssrf.trustEnvProxy` 只跳过对代理主机名的本地 DNS 预检，不改代理本身；localhost 和字面私网 IP 仍拦截。需要整段流量走代理时再设：

```json
{
  "proxy": "http://127.0.0.1:7897"
}
```

包可能把查询发到 Exa 云。这是检索服务，不是本机搜。

### 常用命令

| 命令 | 作用 |
|---|---|
| `/curator off` | 关掉整理层，把原始结果交给模型 |
| `/curator on` | 恢复 summary-review |
| `/websearch` | 不经过模型，自己搜并勾选结果 |
| `/search` | 浏览本 session 已缓存的搜索 |

---

## 和 Herdr 识别 Pi 进程无关

Windows 上 herdr 认不出 `pi`（pi 0.84.3 `dist/bundle/cli.js` + PowerShell `pi.ps1`）是另一件事，见 herdr [#3186](https://github.com/herdrdev/herdr/issues/3186)。web search 是 Pi 进程内部的工具：herdr 侧栏看不到 Pi 时，Pi 自己该能搜还是能搜。

临时启动用 `pi.cmd` 而不是 `pi`，herdr 更容易认出进程。官方修还在 [#3207](https://github.com/herdrdev/herdr/pull/3207)，0.8.2 还没带上。

---

## 以后不要做的

- 再装第二个带 `web_search` 的包。
- 把 xAI `/login` 当成已经有网页搜索。
- 把 `x_search`（搜 X）当成 `web_search`。
- 指望零配置等于「官方文档白名单 + 最近一周 + 多引擎」。
- 在空终端装包却期望某个 Herdr pane 里的旧 Pi 进程立刻生效：要 `/reload` 或重启那个 Pi。
