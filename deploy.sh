#!/bin/bash
# 人间词条 Lifepedia 一键部署脚本
# 用法：bash deploy.sh
# 适用于：首次部署 或 更新部署
# 注意：前端 pwa/dist/ 已随代码一起提交，服务器无需 build

set -e

echo "=== [1/3] 安装 Puppeteer/Chromium 所需系统依赖（Linux only）==="
if command -v apt-get &>/dev/null; then
  sudo apt-get update -qq
  sudo apt-get install -y --fix-missing \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
    libxrandr2 libgbm1 libpango-1.0-0 libpangocairo-1.0-0 \
    libcairo2 libatspi2.0-0 libgtk-3-0 libnss3 libnspr4 \
    libxss1 libx11-xcb1 libxcb1 libfontconfig1 libglib2.0-0 \
    fonts-liberation xdg-utils wget ca-certificates 2>/dev/null || true
  # Ubuntu 22.04+ libasound2 改名；用 dpkg 强制安装绕开 alsa-ucm-conf 404
  if ! ldconfig -p | grep -q libasound.so.2; then
    (cd /tmp && sudo apt-get download libasound2-data alsa-topology-conf libasound2t64 2>/dev/null && \
     sudo dpkg -i --force-depends libasound2-data_*.deb alsa-topology-conf_*.deb libasound2t64_*.deb 2>/dev/null) || true
  fi
else
  echo "  非 apt 系统，跳过系统依赖安装"
fi

echo "=== [2/3] 安装 Node 依赖（express / puppeteer / qrcode / 字体包）==="
npm install

echo "=== [3/3] 重启服务器 ==="
lsof -ti:17497 | xargs kill -9 2>/dev/null || true
nohup node server.mjs > /tmp/server.log 2>&1 &
SERVER_PID=$!
echo "服务器已启动，PID: $SERVER_PID，日志：tail -f /tmp/server.log"

echo ""
echo "=== 部署完成 ==="
echo "本地访问：http://localhost:17497"
echo ""
echo "如需 Pinggy 公网访问，运行："
echo "  nohup bash -c 'while true; do ssh -p 443 -R0:localhost:17497 -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes \"rj9j1gZuYVx+lifepedia.a.pinggy.link@a.pinggy.io\"; sleep 5; done' > /tmp/pinggy.log 2>&1 &"
