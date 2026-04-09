# 人间词条 Lifepedia — 技术部署与运行手册

本文档只描述技术架构、运行链路、部署流程、运维与排障。产品设计理念仅做最小提及。

---

## 0. 当前状态说明（非常重要）

- `pwa/dist/` **已纳入仓库**，服务器更新时通常不需要再执行前端构建。
- 长图接口当前为同步模式：`POST /api/render-share` 直接返回 `{ url }`。
- 长图渲染使用 `puppeteer` + `page.setContent()`，不再走内部 HTTP 路由跳转。

---

## 1. 总体架构

## 1.1 运行时组件

- `pwa/`：前端 PWA（React + TypeScript + Vite + React Router）
- `server.mjs`：Node/Express 网关
  - 托管 `pwa/dist` 静态资源
  - 暴露长图生成 API
  - 调用 Supabase Storage 上传生成图片
- Supabase：
  - PostgREST：业务数据读写
  - Storage：条目图片 + 长图文件
  - Edge Functions：AI 相关能力（前端侧调用）

## 1.2 请求链路

- 普通页面请求：Client -> `server.mjs` -> `pwa/dist/*`
- 业务数据请求：Client -> Supabase PostgREST
- 长图生成请求：
  1) Client `POST /api/render-share`
  2) Server 使用 Puppeteer 渲染 HTML（内存内）
  3) Server 截图 PNG
  4) Server 上传到 Supabase Storage
  5) Server 返回 `{ url }`
  6) Client 直接加载该 URL

---

## 2. 代码结构（部署相关）

```text
lifepedia/
├── server.mjs                 # Node 入口：静态托管 + 长图 API
├── deploy.sh                  # 一键部署脚本（依赖安装 + 服务重启）
├── package.json               # 根依赖（express/puppeteer/qrcode 等）
├── pwa/
│   ├── src/                   # 前端源码
│   ├── dist/                  # 前端构建产物（已纳入 git）
│   └── package.json           # 前端依赖与脚本
├── fonts/                     # 字体资源（如有）
└── DEPLOY.md                  # 本文档
```

---

## 3. 环境要求

- OS：Ubuntu 22.04/24.04（推荐）
- Node.js：20.x（推荐）
- npm：10+
- 端口：默认 `17497`
- 外网访问方式（二选一）：
  - Pinggy 隧道（开发/演示）
  - Nginx 反代 + 域名（生产）

---

## 4. 新服务器首次部署（从零）

## 4.1 安装 Node.js 20

```bash
apt-get update
apt-get install -y curl ca-certificates gnupg
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
  > /etc/apt/sources.list.d/nodesource.list
apt-get update
apt-get install -y nodejs
node -v
npm -v
```

## 4.2 拉代码并安装依赖

```bash
cd ~
git clone https://github.com/overlordkim/lifepedia.git
cd lifepedia
npm install
```

## 4.3 安装 Puppeteer 运行库（Linux 必需）

```bash
apt-get update
apt-get install -y --fix-missing \
  ca-certificates fonts-liberation xdg-utils wget \
  libatk1.0-0 libatk-bridge2.0-0 libcups2 libdbus-1-3 \
  libdrm2 libgbm1 libglib2.0-0 libnspr4 libnss3 \
  libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxdamage1 \
  libxext6 libxfixes3 libxrandr2 libxrender1 libxshmfence1 \
  libxss1 libxtst6 libcairo2 libpango-1.0-0 libpangocairo-1.0-0
apt-get install -y libasound2 2>/dev/null || apt-get install -y libasound2t64
```

## 4.4 安装中文字体（长图中文不显示方框）

```bash
apt-get install -y fonts-noto-cjk fonts-wqy-zenhei fonts-wqy-microhei
fc-cache -f -v
```

## 4.5 启动服务

```bash
cd ~/lifepedia
pkill -f "node server.mjs" 2>/dev/null || true
nohup node server.mjs > /tmp/server.log 2>&1 &
sleep 2
tail -30 /tmp/server.log
```

预期日志：

```text
Server running on http://localhost:17497
```

---

## 5. 功能验收（先内网，再公网）

## 5.1 内网验收（必须先过）

```bash
curl -s --max-time 90 -X POST http://localhost:17497/api/render-share \
  -H 'Content-Type: application/json' \
  -d '{"entry":{"id":"t","title":"test","author_id":"x","author_name":"test","category":"moment","scope":"public","sections":[]}}'
```

预期返回：

```json
{"url":"https://...supabase...png"}
```

## 5.2 公网验收（Pinggy）

### 固定域名（含 force 抢占）

```bash
pkill -f "a.pinggy.io" 2>/dev/null || true
nohup ssh -N -p 443 -R0:localhost:17497 \
  -o StrictHostKeyChecking=no \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes \
  "rj9j1gZuYVx+lifepedia.a.pinggy.link+force@a.pinggy.io" \
  > /tmp/pinggy.log 2>&1 &
sleep 3
tail -50 /tmp/pinggy.log
```

如果日志出现 token 冲突，请确认旧服务器已关闭隧道或继续使用 `+force`。

---

## 6. 日常更新流程（推荐）

由于 `pwa/dist` 已入仓，日常更新通常不需要构建：

```bash
cd ~/lifepedia
git pull
npm install
pkill -f "node server.mjs" 2>/dev/null || true
nohup node server.mjs > /tmp/server.log 2>&1 &
```

仅当你确认 `pwa/dist` 未更新或手工改了前端源码，才在部署机执行：

```bash
cd ~/lifepedia/pwa
npm run build
```

---

## 7. 进程托管（生产建议）

## 7.1 PM2

```bash
npm i -g pm2
cd ~/lifepedia
pm2 start server.mjs --name lifepedia
pm2 save
pm2 startup
```

常用命令：

```bash
pm2 status
pm2 logs lifepedia
pm2 restart lifepedia
pm2 stop lifepedia
```

## 7.2 Nginx（可选）

如改用正式域名，建议使用 Nginx 反向代理到 `127.0.0.1:17497`，并配置 HTTPS。

---

## 8. 关键配置与常见变更点

- `server.mjs` 顶部：
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
- 默认端口：
  - `PORT` 环境变量，默认 `17497`
- 长图渲染参数（稳定性相关）：
  - `deviceScaleFactor`
  - `setContent` timeout
  - 重试次数与间隔

---

## 9. 故障排查（按优先级）

## 9.1 服务没起来

```bash
lsof -ti:17497
tail -100 /tmp/server.log
node server.mjs
```

## 9.2 长图报 Puppeteer 缺库

报错关键字：`error while loading shared libraries`  
执行第 4.3 节系统库安装命令。

## 9.3 中文是方框

执行第 4.4 节字体安装命令并 `fc-cache -f -v`。

## 9.4 Pinggy 无法连接/token 冲突

错误：`A tunnel with the same token is already active`

处理：
1) 杀旧隧道：`pkill -f "a.pinggy.io"`  
2) 使用 `+force` 登录。

## 9.5 长图超时或崩溃

- 看 `/tmp/server.log` 是否有 `Target closed` / `timeout`
- 先降低并发（一次只点一张）
- 降低渲染参数（DPR）
- 升级服务器规格（推荐 4G+，16G 最稳）

---

## 10. 运维日志与检查命令速查

```bash
# 服务日志
tail -f /tmp/server.log

# 隧道日志
tail -f /tmp/pinggy.log

# 端口监听
lsof -ti:17497

# Node 进程
ps aux | grep "node server.mjs" | grep -v grep
```

---

## 11. 一句话心智模型

Lifepedia 的技术核心是“前端静态托管 + Supabase 数据层 + Node 长图渲染网关”。  
部署优先级永远是：先保证 `server.mjs` 可用，再保证长图 API 通，再考虑视觉与体验调优。
