# RemoteControl（Windows）— 暂不落地

目标对应 [功能对照.md](../功能对照.md) §1：在 iOS / Android 上连接并控制本机 Herdr。

**结论（2026-08-29）：暂停。** 没有同时满足 Windows 主机、局域网或 Tailscale、双端可用、安全模型可接受的现成方案。试过的插件都已卸载，本机不留 relay。

对照对象是 Orca 的 Companion（`D:\Projects\orca`）：桌面和手机是同一套 Runtime，不是 Herdr 插件，不能搬过来装。

---

## 选型

| 方案 | 形态 | Windows | 手机 | 传输 / 门禁 | 结论 |
|---|---|---|---|---|---|
| [mattbidinger/herdr-pocket](https://github.com/mattbidinger/herdr-pocket) | Node 网页 / PWA | 主战场 | iOS+Android 浏览器 | 默认 `0.0.0.0`、明文 HTTP、一次性 QR 配对 | **已试、已卸。** 网页码是 ASCII `<pre>`，相机扫不出。 |
| [dcolinmorgan/herdr-remote](https://github.com/dcolinmorgan/herdr-remote) | Python relay + 自带网页 | 有 `start.ps1` | 浏览器 / Telegram | 一把共享 `HERDR_RELAY_TOKEN`；LAN 直连是 HTTP / `ws://` | **已试、功能可用、已卸。** 公司大局域网不安心。 |
| [Tomyail/herdr-connect](https://github.com/Tomyail/herdr-connect) | 独立 Go daemon + 原生 iOS | 有 zip daemon | iOS TestFlight；Android 未发 | 真 QR、每设备 token、TLS pin、mDNS | 未装。最接近 Orca 配对；不是 `herdr plugin`。 |
| [AltanS/collie](https://github.com/AltanS/collie) | PWA + Bun bridge | 实验（清单无 Windows） | iOS+Android 主屏幕 | 默认 `127.0.0.1` + `tailscale serve` | 未装。安全正规；本机 Windows 要自己拉 bridge。 |
| [ZingerLittleBee/Heeler](https://github.com/ZingerLittleBee/Heeler) | 原生 iOS + 配对插件 | 需 OpenSSH Server | 仅 iOS | SSH；可用 Tailscale 当虚拟 LAN | 未装。无 Android。 |
| [0cv/herdr-mobile-relay](https://github.com/0cv/herdr-mobile-relay) / [benkraus/herdr-mobile](https://github.com/benkraus/herdr-mobile) | 手机 Web / 原生 + relay | **不支持** | iOS+Android | 隧道 / WebRTC | **不要装。** |
| [lntvan166/paddock](https://github.com/lntvan166/paddock) | 手机仪表盘 | 安装偏 Unix | PWA | 禁止绑 `0.0.0.0`，走 Cloudflare tunnel | 不对 LAN 目标。 |
| [maedana/herdr-agents-bridge](https://github.com/maedana/herdr-agents-bridge) | 扫 QR 网页 | 仅 Linux/macOS | 浏览器 | LAN QR | 无 Windows。 |
| 官方 | 手机 SSH 再跑 `herdr` | 有 | 任意 SSH 客户端 | SSH | 能用，不是 App。 |
| Orca Companion | 桌面 Electron + 原生 App | 一等公民 | iOS App Store + Android APK | 未配对 loopback；配对后才 `0.0.0.0`；每设备 token；TLS 指纹；E2EE；可优先广告 Tailscale `100.x` | 参照，不是 Herdr 方案。 |

不要叠装两套遥控面。

---

## 本机试用（均已卸干净）

当时 Herdr 0.8.2。下列插件 **现在都不该出现在** `herdr plugin list` 里。

### herdr-pocket

```powershell
herdr plugin install mattbidinger/herdr-pocket --yes
# 插件目录里 node bin/herdr-pocket.js → 默认 0.0.0.0:8787
```

- 安装本身无 `startup` / `events`，不改 Herdr 配置。
- 配对页 `http://127.0.0.1:8787/pair` 上的码是终端 ASCII 画在 `<pre>` 里，不是标准 QR 图。
- 已 `herdr plugin uninstall`，并删掉插件 checkout 与 config 目录。`8787` 不再监听。

### herdr-remote

```powershell
herdr plugin install dcolinmorgan/herdr-remote --yes
# ~/.config/herdr-remote/config.env : HERDR_RELAY_HOST=0.0.0.0, HERDR_TUNNEL_MODE=none
# secrets.env : HERDR_RELAY_TOKEN=…
# 插件目录 .\relay\start.ps1
```

- 功能：手机打开带 token 的 URL，能列出 Agent、看输出、回批准。网页是 relay 自己 serve 的，不靠扫码。
- **不跟 Herdr 生命周期走。** 没有 `startup`。打开 Herdr 不会自动起 relay；关掉 TUI 也不会停。要停就 Ctrl+C `start.ps1`。插件只挂了一条 `pane.agent_status_changed` → 本机 UDP `8376`。
- 已卸载插件，并删除 `~\.config\herdr-remote`、插件 config、`%LOCALAPPDATA%\herdr-remote`。`8375` 不再监听。

---

## herdr-remote 安全模型（卸掉的原因）

门禁就是 **一把共享 token**。LAN 直连是 **明文 HTTP + `ws://`**，没有 TLS。

- 不带 token → 401；带 `?token=` 或 `Authorization: Bearer` → 整页控制面。
- 有 token 时不再校验 WebSocket Origin。
- 全网共用一把钥匙，不能按设备撤销，只能整把轮换。
- `?token=` 会进浏览器历史、聊天记录、公司 HTTP 代理日志。
- 交换机 / 开放 Wi-Fi 抓包能看到 token 和终端内容。
- 拿到完整 URL 的人权限与操作者相同（看、回、发键、打断），不是只读。
- Relay 还会 mDNS 广播 `_herdr-remote._tcp`，同网段能发现「8375 上有 herdr-remote」。

绑 `127.0.0.1` 则手机不能直接打局域网 IP；远程必须再加 Tailscale / 隧道。默认 loopback 是为这个，不是「不能远程」。

若以后再装：Relay 只听 `127.0.0.1`，手机走 Tailscale 或 HTTPS 反代；不要在公司大局域网绑 `0.0.0.0`；不要把带 token 的 URL 发到群里。

---

## Orca 为何体感更好（对照，不移植）

Orca 桌面进程内嵌 Runtime WebSocket（默认 `6768`），手机是原生 Companion，不是 sidecar 网页。

- 未配对只听 `127.0.0.1`；生成配对 QR 才扩到 `0.0.0.0`，并维护 Windows 防火墙规则 `Orca Mobile Pairing`。
- QR 是 `qrcode` 生成的 PNG；载荷 `orca://pair?code=…` 含 endpoint、**每设备** token、桌面 E2EE 公钥、可选 Relay 邀请。
- `wss` 自签证书指纹写进配对码；应用层再做 NaCl/ECDH。中继读不了终端。
- 自动广告优先 Tailscale `100.x`，再才是物理 LAN；不自动广告 Docker / 默认交换机。
- 关掉 Orca 窗口，端口一起没。

Herdr 没有对等的官方 Companion。最接近配对模型的是 herdr-connect，不是 herdr-remote。

---

## 以后若再启动

1. 先读本页和功能对照 §1，不要按旧「处理」栏去装 herdr-remote / pocket。
2. 接受明文共享 token + 仅 Tailscale：再考虑 herdr-remote，绑定必须 loopback。
3. 主力 iPhone、要真 QR / 每设备凭证：herdr-connect 或 Heeler + Tailscale SSH。
4. 要 Tailscale 身份、双端 PWA、并接受 Windows 实验：Collie。
5. 必须双端原生 + LAN：社区没有，需要 fork herdr-connect 补 Android，不要另起一套明文 relay。
