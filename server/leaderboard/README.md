> 游戏测试版已接入：本机随机玩家 ID + 可修改昵称；每次 52 周通关只上传当前局，支持 `deported` 与 `rooted` 两种结局。当前榜仍使用 `la-52w-v1`。以下 CloudKit 身份设计为后续正式版方案，测试版不读取 iCloud 姓名。交互和队列说明见 [世界排名](../../docs/WORLD-LEADERBOARD.md)。

# Surviving LA 世界榜服务

一个 FastAPI 容器处理上传和查询，SQLite 数据库放在独立 Docker volume。可选的 Caddy 容器负责 HTTPS。第一版信任客户端成绩，不验证存档、随机种子或操作回放。

**交付状态：API 与 IP HTTPS 容器已部署在 VPS `2.24.206.66`。公网地址 `https://2.24.206.66:18443`，服务器本机 API 为 `http://127.0.0.1:18080`。游戏“生存日记”底部的“世界排名”已接入逐局 Top 50 查询；自动上传仍待实现。实际部署记录见 [DEPLOYMENT.md](DEPLOYMENT.md)。**

## VPS 快速启动

这台 VPS 的实际启动方式已由 `.env` 的 `COMPOSE_FILE=compose.yaml:compose.ip-https.yaml` 固定，直接执行 `docker compose up -d --build --wait` 会启动 API 和 Caddy。Nginx 的独立 IP 站点将 HTTP-01 验证请求转发到回环端口 18081；Caddy 在 18443 提供受信任的 IP 证书并自动续期。下列两种域名方案供迁移/其他 VPS 使用，不要同时启动域名 Caddy 和 IP Caddy。

需要 Linux VPS、Docker Engine + Compose 插件。把本目录上传到 VPS，例如 `/opt/survive-in-la-leaderboard`。先检查已有服务占用，避免接管正在使用的 80/443 端口。

### 已有 Nginx / Caddy / 其他 HTTPS 反向代理

```sh
cd /opt/survive-in-la-leaderboard
docker compose up -d --build --wait
curl --fail http://127.0.0.1:8080/healthz
```

在已有代理中把你的榜单域名转发到 `127.0.0.1:8080`，上传请求体限制为 8 KB。API 端口仅绑定 VPS 回环地址。如果代理也在容器里，要用共享 Docker 网络转发到 API 的 8000 端口，不能用代理容器自己的 `127.0.0.1`。

### 没有 HTTPS 反向代理

1. 为榜单域名设置指向 VPS 的 DNS A 记录；若设置 AAAA，IPv6 也必须能访问这台 VPS。
2. 在云厂商安全组及系统防火墙放通 TCP 80、443。
3. 保证这两个端口没有被其他服务占用。

```sh
cd /opt/survive-in-la-leaderboard
cp .env.example .env
```

编辑 `.env` 中的域名和证书联系邮箱，然后启动：

```sh
docker compose -f compose.yaml -f compose.https.yaml up -d --build --wait
docker compose -f compose.yaml -f compose.https.yaml logs --tail=50 caddy
curl --fail https://你的榜单域名/healthz
```

`--wait` 确认 API 健康和容器运行；最后的 HTTPS 请求才确认域名、证书、代理的完整链路。应用 Base URL 使用 `https://你的榜单域名`。没有域名时可以先从 VPS 本机测试 API；正式游戏接入待 HTTPS 地址就绪，不在游戏里放开全局明文网络限制。也可以配置 IP 地址证书，但需另配短期证书自动续期；本目录的域名 Caddy 配置不能直接当作公网 IP 证书配置使用，参见 [Let's Encrypt IP 证书说明](https://letsencrypt.org/2026/03/11/shorter-certs-certbot)。

Docker 官方安装说明：[Ubuntu](https://docs.docker.com/engine/install/ubuntu/)、[Debian](https://docs.docker.com/engine/install/debian/)。实际部署时根据 VPS 系统选择，不执行未知脚本或替换现有 Docker 配置。

## 数据与运行

- 数据卷：`survive-in-la-leaderboard_leaderboard_data`；数据库：`/data/leaderboard.sqlite3`。
- `docker compose restart api` 或重新构建不会清除数据。不要用 `docker compose down -v`，它会删除数据卷。
- API 以非 root 用户运行；镜像文件只读；日志轮转；进程退出自动重启。单纯 unhealthy 不触发 Docker 自动重启，应查看日志解决原因。
- API 单进程、SQLite WAL；适合第一版单 VPS 部署，不支持多台 VPS 共享同一数据库文件。
- Python 依赖完整锁定在 `requirements.txt`，直接依赖保留在 `requirements.in`。基础镜像采用 Python 3.12 / Caddy 2 官方镜像标签；它们会收到更新，部署时可记录镜像 digest。
- 第一版无反作弊，也没有服务端 Apple 身份认证。`X-Player-ID` 是客户端声明的标识，不是登录凭证。不要把公共榜单中的 run ID 当作玩家 ID。服务器仅保存玩家 ID 的 SHA-256 派生值，公开接口不返回它。
- 只限制格式、请求大小、整数范围和重复记录；不判断分数是否符合游戏过程。没有写死在游戏里的共享管理员密钥，没有公开数据库或管理端口。

## 备份与恢复

在 VPS 服务目录执行：

```sh
sh backup.sh
```

备份使用 SQLite online backup，包含 WAL 中尚未合并的写入；先验证完整性，再生成 `backups/leaderboard-时间-进程号.sqlite3`。失败时不会留下看似成功的文件。应定期把备份复制到 VPS 以外的位置。本交付不自动创建定时任务。

恢复前先备份当前库，然后停掉 API，在停止状态移除 WAL/SHM 并替换数据库：

```sh
docker compose stop api
docker compose run --rm --no-deps -T --user 10001:10001 api python -c 'import os,sys; from pathlib import Path; p=Path(os.environ["DATABASE_PATH"]); [Path(str(p)+s).unlink(missing_ok=True) for s in ("-wal","-shm")]; p.write_bytes(sys.stdin.buffer.read())' < backups/要恢复的文件.sqlite3
docker compose start api
curl --fail http://127.0.0.1:8080/healthz
```

恢复前应验证备份文件可读且 `PRAGMA integrity_check` 返回 `ok`；保留恢复前备份。不要覆盖正在运行的数据库。

## API

本地可访问 `/docs` 或 `/openapi.json` 查看准确字段。客户端超时建议 10 秒。

| 请求 | 用途 | 身份 |
|---|---|---|
| `GET /healthz` | 存储可用性 | 不需要 |
| `PUT /v1/player` | 建立/修改昵称 | `X-Player-ID` |
| `POST /v1/runs` | 幂等上传终局 | `X-Player-ID` |
| `GET /v1/leaderboard?limit=100` | 世界前 100 + 我的最高排名 | 可选 `X-Player-ID` |
| `GET /v1/rankings?limit=50` | 游戏内世界排名：已提交存档 Top 50 | 不需要 |
| `GET /v1/me/runs?limit=20&before=123` | 本人历史，按收到时间倒序翻页 | `X-Player-ID` |

### 上传

每次通关只提交当前通关存档的本局成绩：`POST /v1/runs` 接收单个对象，不接收存档数组或历史成绩列表。本局分数低于历史最高时也提交本局实际分数。客户端不得因本次通关而扫描或上传其他 Profile 和历史记录；断网补传只逐条重试此前入队的通关记录。

`X-Player-ID` 当前传客户端持久化的 `test-UUID`；未来可接入 CloudKit 的 `userRecordID().recordName`，但需同时设计身份迁移，不能直接换 ID 冒充同一玩家。下例是测试占位值。终局的 `day` 在引擎中可能是 53，`weeks_survived` 应取 `min(day, totalDays)`，即 52。

```sh
curl --fail-with-body http://127.0.0.1:8080/v1/runs \
  -H 'Content-Type: application/json' \
  -H 'X-Player-ID: demo-player-4821' \
  --data '{"run_id":"8fd29fe9-a4eb-4ff3-bd41-fb2bf861f604","display_name":"洛城旅人4821","ruleset":"la-52w-v1","net_worth":28450,"profile_id":1,"weeks_survived":52,"ending":"deported","health":38,"experience_count":12,"used_purchases":false,"completed_at":"2026-09-04T20:00:00Z","app_version":"0.2"}'
```

新记录返回 **201**；同一玩家、同一局、相同内容重试返回 **200** 和 `duplicate: true`。已有同局但内容或归属不同返回 **409**，不会覆盖成绩。昵称不参与不可变内容比较：补传旧记录不会把新昵称改回去。首次上传可创建默认昵称，之后改名用 `PUT /v1/player`。

响应包括 `run_id`、`is_personal_best`、`my_best`（`rank` 等）、`total_players`、`as_of`。当前结算页只显示“本局已上传世界排名”；`my_best` 属于个人最高记录，不能把其名次标成“本局排名”。

### 查榜

游戏“生存日记 → 世界排名”使用 **`GET /v1/rankings?limit=50`**：按每条已提交的通关记录排名，同一玩家的不同局可分别出现；不按玩家合并。最多 50 条，未满 50 则只显示实际记录。返回 `as_of`、`total_players`、`total_runs`、`entries`，每条包含提交昵称、该局 `app_version`、`profile_id`、`net_worth`、健康、事件种数、充值标记、通关时间及服务器接收时间 `received_at`。版本来自该局提交值，不使用当前服务器或当前 App 版本替代。

```sh
curl --fail 'https://2.24.206.66:18443/v1/rankings?limit=50'
```

以下旧的 `/v1/leaderboard` 接口继续提供按玩家合并的最高成绩，保留兼容；不是新的日记 Top 50 页面所用接口。

```sh
curl --fail http://127.0.0.1:8080/v1/leaderboard \
  -H 'X-Player-ID: demo-player-4821'
```

返回 `ruleset`、`as_of`、`total_players`、`total_runs`、`entries` 和 `my_best`。每行包括名次、昵称、净资产、Profile、健康、事件种数、是否使用充值、完成时间和 `is_me`；没有 Apple 原始标识、邮件或存档日记。`my_best` 独立查询，即使排名在第 100 名以外也能看到；未通关/未提供身份时为 `null`。响应禁止共享缓存，应用可自行保存最近一次成功结果作为离线只读缓存。

历史接口使用返回的 `next_before` 翻页；为 `null` 时结束。不同玩家身份的历史分开返回，但本版身份为客户端声明，不能作为敏感资料的访问控制。

### 排名约定

- 榜单规则：`la-52w-v1`，52 周通关后的最终净资产，支持负数；提前死亡/旧 40 周结局留在本机。
- 世界 Top 50 按每局分别占行，同一玩家可以多次上榜。仅兼容接口 `/v1/leaderboard` 合并为每个玩家的最高分。客户端始终逐局提交。
- 按净资产降序；同分按服务器首次接收顺序排列。重新上传不改变先后；客户端的完成时间只用于展示。
- 充值成绩在同一榜单，用 `used_purchases` 标注。此字段也由客户端声明。
- 游戏经济规则有重大变化时应新增 ruleset 并做显式迁移/分榜，不把不可比的旧成绩混入。

## 本地验证

使用 Python 3.12：

```sh
python3.12 -m venv .venv
.venv/bin/pip install -r requirements-test.txt
.venv/bin/python -m unittest -v
DATABASE_PATH=/tmp/survive-la-test.sqlite3 .venv/bin/uvicorn app:app --host 127.0.0.1 --port 8080
```

17 项测试已通过，涵盖最高分合并、负分/同分、并发重试、ID 冲突、100 名外个人排名、昵称更新、结构限制、超高分直接采信、历史翻页、重启保留和备份恢复，以及逐局 Top 50 的版本字段、同玩家多局和条数上限。VPS 的公网 HTTPS、真实上传/查询已验证；客户端新增上传队列及终局流程测试；原生公网联调已验证两局分数独立上传和查询，临时数据验证后清理。

设计依据：[FastAPI 容器部署](https://fastapi.tiangolo.com/deployment/docker/)、[Compose 服务定义](https://docs.docker.com/reference/compose-file/services/)、[Caddy HTTPS](https://caddyserver.com/docs/quick-starts/https)、[SQLite backup](https://docs.python.org/3.12/library/sqlite3.html#sqlite3.Connection.backup)。
