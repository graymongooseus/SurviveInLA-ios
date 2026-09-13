# VPS 部署记录

最近验证：2026-09-05 21:35 UTC（洛杉矶时间 2026-09-05 14:35）。

| 项目 | 实际配置 |
|---|---|
| VPS | `2.24.206.66`，Ubuntu 22.04.5，x86_64 |
| 目录 | `/opt/survive-in-la-leaderboard` |
| 容器 | `survive-in-la-leaderboard-api-1`、`survive-in-la-leaderboard-caddy-ip-1` |
| Compose 项目 | `survive-in-la-leaderboard` |
| 服务端口 | `127.0.0.1:18080` → 容器 `8000` |
| 状态 | `healthy`；`restart: unless-stopped` |
| 数据卷 | `survive-in-la-leaderboard_leaderboard_data` |
| 数据库 | 容器内 `/data/leaderboard.sqlite3` |
| 最近备份 | `/opt/survive-in-la-leaderboard/backups/leaderboard-20260905T213458Z-3850276.sqlite3` |
| 公网 HTTPS | `https://2.24.206.66:18443` |
| Top 50 查询 | `GET /v1/rankings?limit=50` |
| 证书 | Let's Encrypt IP 短期证书，Caddy 自动续期 |

现有 80、443 由 Nginx 使用，8080 已有邮件服务。API 保持本机 18080，新增 Caddy 对外 18443 及本机验证端口 18081。

新增 Nginx 配置 `/www/server/panel/vhost/nginx/survive-in-la-ip.conf`，仅匹配 Host 为 `2.24.206.66` 的 HTTP 请求，将 `/.well-known/acme-challenge/` 转发到 `127.0.0.1:18081`。原有域名网站、443 监听、DNS、防火墙不变。配置通过 `nginx -t` 后平滑重载。

`.env` 设置 `LOCAL_PORT=18080`、`LEADERBOARD_IP=2.24.206.66`、`COMPOSE_FILE=compose.yaml:compose.ip-https.yaml`。Caddy 证书/ACME 账户保存于 `survive-in-la-leaderboard_caddy_ip_data`，不要删除此卷；续期仍需公网 80 的验证路径可达。

已验证：

- 实际 Linux Docker 镜像构建，非 root 用户对数据卷读写正常。
- 通过 SSH 隧道请求真实 API：首次上传 201，相同记录重试 200 且 `duplicate=true`，本人排名查询正确。
- 重启 API 后，先前的净资产与 run ID 保持一致。
- 在线备份 `integrity_check=ok`，内容含重启前上传的记录。
- 删除本次创建的唯一临时测试记录后，世界榜回到 0 玩家、0 记录，生成干净初始备份。没有保留虚构玩家作为生产数据。

当前 VPS 启动与查看：

```sh
cd /opt/survive-in-la-leaderboard
docker compose up -d --build --wait
docker compose ps
curl --fail http://127.0.0.1:18080/healthz
sh backup.sh
```

手机/模拟器使用 `https://2.24.206.66:18443/v1/rankings?limit=50`。已通过标准证书验证（未跳过 TLS 校验），并完成公网提交及游戏 UI 读取验证。三个界面验收记录已按明确 run ID 清理，正式榜单为空；客户端现已接入通关自动上传、昵称管理和持久化重试队列。

IP 证书方案依据 [Let's Encrypt 公告](https://letsencrypt.org/2026/03/11/shorter-certs-certbot) 和 [Caddy ACME 配置](https://caddyserver.com/docs/caddyfile/directives/tls)。以后切换域名时更新游戏 `WorldRankingStore.endpoint`，并另行配置域名证书。

凭据没有写进工程、镜像、环境文件或本文档。

## 测试版上传接入 · 2026-09-05（洛杉矶）

- 上线前备份：`backups/leaderboard-20260906T000821Z-3900385.sqlite3`。
- API 数据库版本升级到 2，旧记录默认 `ending=deported`，新增支持 `rooted`。保留原 run ID、去重指纹和排序方式。
- 使用 `docker compose up -d --build --wait` 更新 API；Caddy 保留既有 HTTPS 配置，两个容器均健康。
- 原生 XCTest 经公网 HTTPS 上传两个独立完成的存档，分数 4321 / 1234，提交版本 1.1 (2)，再使用游戏的 WorldRankingStore 成功读取并比对。
- 临时玩家及其两条明确 run ID 的记录已清理，未保留虚构成绩。
