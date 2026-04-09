# 人间词条 Lifepedia — 部署指南

## 一、项目结构

```
lifepedia/
├── server.mjs          # Express 服务器（托管 PWA + 长图 API）
├── package.json        # 根依赖：express、puppeteer、qrcode
├── .env                # 环境变量（见下方说明，不提交到 git）
├── logo_transparent.png
└── pwa/                # React PWA 源码
    ├── src/
    ├── dist/           # 构建产物（需先 build）
    └── package.json
```

---

## 二、环境要求

- **Node.js** ≥ 18（使用了原生 `fetch`）
- **npm** ≥ 9

---

## 三、环境变量

在项目根目录创建 `.env`（已在 `.gitignore` 中排除）：

```env
# 火山引擎 Ark（Doubao 模型）
ARK_API_KEY=your_ark_api_key
ARK_BASE_URL=https://ark.cn-beijing.volces.com/api/v3
ARK_MODEL=doubao-seed-2-0-lite-260215

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key

# Spider（URL 内容抓取）
SPIDER_API_KEY=your_spider_key
```

> **注意**：`server.mjs` 中已硬编码了 Supabase URL 和 anon key（用于服务端长图上传），
> 如果换了 Supabase 项目，需要同步更新 `server.mjs` 顶部的两个常量。

---

## 四、首次部署步骤

### 1. 安装依赖

```bash
# 根目录（Express 服务器依赖）
npm install

# PWA 前端依赖
cd pwa && npm install && cd ..
```

### 2. 构建前端

```bash
cd pwa
npm run build   # 产物输出到 pwa/dist/
cd ..
```

### 3. 启动服务器

```bash
node server.mjs
# 默认监听 0.0.0.0:17497
# 可通过 PORT 环境变量修改端口：PORT=3000 node server.mjs
```

---

## 五、通过 Pinggy 暴露到公网（临时隧道）

Pinggy 是一个 SSH 隧道服务，适合开发/演示用途。

```bash
# 格式：ssh -p 443 -R0:localhost:<本地端口> <TOKEN>+<自定义域名>@a.pinggy.io
ssh -p 443 -R0:localhost:17497 \
  -o StrictHostKeyChecking=no \
  -o ServerAliveInterval=30 \
  "rj9j1gZuYVx+lifepedia.a.pinggy.link@a.pinggy.io"
```

成功后访问：`https://lifepedia.a.pinggy.link`

**注意**：
- Pinggy 免费隧道会不定时断开，需要手动重连
- 每次重连后 HTTPS URL 不变（固定域名已绑定）
- 若迁移到正式服务器（有公网 IP），直接通过 Nginx/反向代理暴露，无需 Pinggy

---

## 六、正式服务器部署建议（Linux / VPS）

### 用 PM2 保活进程

```bash
npm install -g pm2
pm2 start server.mjs --name lifepedia
pm2 save
pm2 startup   # 设置开机自启
```

### Nginx 反向代理（可选，支持 HTTPS）

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:17497;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_read_timeout 60s;   # 长图生成最多需要约 30s
        proxy_send_timeout 60s;
    }
}
```

---

## 七、更新部署（后续迭代）

```bash
git pull

# 重新构建前端
cd pwa && npm run build && cd ..

# 重启服务器
pm2 restart lifepedia
# 或直接 kill 再启动：
# lsof -ti:17497 | xargs kill -9 && node server.mjs
```

---

## 八、关键服务说明

| 服务 | 说明 |
|------|------|
| **Supabase** | 数据库（entries、users、comments 等表）+ Storage（图片存储）+ Edge Functions（AI 对话、图片生成、URL 爬取） |
| **火山引擎 Ark** | AI 对话模型（doubao-seed-2-0-lite）+ 图片生成（doubao-seedream-5-0） |
| **Puppeteer** | 服务端长图生成（首次启动会自动下载 Chromium，约 200MB） |
| **GitHub Pages** | 微信扫码中转页（`lifepedia-redirect` 仓库，已部署，无需操作） |

---

## 九、Puppeteer 在 Linux 服务器上的注意事项

服务器通常缺少 Chromium 运行所需的系统库，需要安装：

```bash
# Ubuntu / Debian
apt-get install -y \
  libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
  libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 \
  libxfixes3 libxrandr2 libgbm1 libasound2

# 或者使用系统 Chromium（跳过 puppeteer 自带的下载）：
# PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true npm install
# 然后在 server.mjs getBrowser() 里加：executablePath: '/usr/bin/chromium-browser'
```
