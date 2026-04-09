#!/bin/bash
# 人间词条 Lifepedia 一键部署脚本
# 用法：bash deploy.sh
# 适用于：首次部署 或 更新部署

set -e

echo "=== [1/4] 安装根目录依赖（express / puppeteer / qrcode）==="
npm install

echo "=== [2/4] 安装 PWA 前端依赖 ==="
cd pwa && npm install && cd ..

echo "=== [3/4] 构建前端（输出到 pwa/dist/）==="
cd pwa && npm run build && cd ..

echo "=== [4/4] 重启服务器 ==="
# 停掉旧进程（如果有）
lsof -ti:17497 | xargs kill -9 2>/dev/null || true

# 用 nohup 后台启动，日志写到 /tmp/server.log
nohup node server.mjs > /tmp/server.log 2>&1 &
SERVER_PID=$!
echo "服务器已启动，PID: $SERVER_PID，日志：tail -f /tmp/server.log"

echo ""
echo "=== 部署完成 ==="
echo "本地访问：http://localhost:17497"
echo ""
echo "如需 Pinggy 公网访问，运行："
echo "  nohup bash -c 'while true; do ssh -p 443 -R0:localhost:17497 -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes \"rj9j1gZuYVx+lifepedia.a.pinggy.link@a.pinggy.io\"; sleep 5; done' > /tmp/pinggy.log 2>&1 &"
