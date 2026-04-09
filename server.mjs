import express from 'express'
import puppeteer from 'puppeteer'
import QRCode from 'qrcode'
import path from 'path'
import fs from 'fs'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const PORT = parseInt(process.env.PORT || '17497', 10)

const SUPABASE_URL = 'https://okoeauotvsgjwhydfgsk.supabase.co'
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9rb2VhdW90dnNnandoeWRmZ3NrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2Mzk4OTksImV4cCI6MjA5MTIxNTg5OX0.p5UDU3QJi7OIWOEL8Sp8Ky6Cm_j1bf9v8R1xRbN6Wgo'

async function uploadShareImage(pngBuffer) {
  const name = `share-${Date.now()}-${Math.random().toString(36).slice(2)}.png`
  const uploadURL = `${SUPABASE_URL}/storage/v1/object/images/shares/${name}`
  const res = await fetch(uploadURL, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      'Content-Type': 'image/png',
      'x-upsert': 'true',
    },
    body: pngBuffer,
  })
  if (!res.ok) {
    const msg = await res.text()
    throw new Error(`Storage upload failed: ${res.status} ${msg}`)
  }
  return `${SUPABASE_URL}/storage/v1/object/public/images/shares/${name}`
}

function avatarURL(userId) {
  return `${SUPABASE_URL}/storage/v1/object/public/images/avatars/${userId}.jpg`
}

const logoBase64 = (() => {
  const p = path.join(__dirname, 'logo_transparent.png')
  if (fs.existsSync(p)) return 'data:image/png;base64,' + fs.readFileSync(p).toString('base64')
  return ''
})()

// WQY 内嵌兜底字体（保证中文不乱码）
const fontBase64 = (() => {
  const p = path.join(__dirname, 'fonts', 'wqy-microhei.ttc')
  if (fs.existsSync(p)) return 'data:font/ttc;base64,' + fs.readFileSync(p).toString('base64')
  return ''
})()


const CATEGORY_META = {
  person:    { label: '人物' },
  place:     { label: '栖居' },
  companion: { label: '相伴' },
  taste:     { label: '滋味' },
  keepsake:  { label: '旧物' },
  moment:    { label: '际遇' },
  era:       { label: '流年' },
}

const SCOPE_META = {
  private:       { label: '私人' },
  collaborative: { label: '合编' },
  public:        { label: '公共' },
}

function escHtml(s) {
  if (!s) return ''
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}

function renderWiki(text) {
  if (!text) return ''
  return escHtml(text)
    .replace(/\[\[([^\]]+)\]\]/g, '<span class="wk-blue">$1</span>')
    .replace(/\{\{([^}]+)\}\}/g, '<span class="wk-red">$1</span>')
    .replace(/\[来源请求\]/g, '<sup class="wk-src">[来源请求]</sup>')
}

function buildCardHTML(entry, qrDataURL) {
  const catMeta = CATEGORY_META[entry.category] || { label: entry.category, emoji: '📝' }
  const scpMeta = SCOPE_META[entry.scope] || { label: entry.scope, emoji: '🌐' }
  const coverUrl = entry.cover_image_url || (entry.sections || []).find(s => s.image_refs?.length)?.image_refs?.[0] || ''
  const avUrl = avatarURL(entry.author_id)

  const coverBlock = coverUrl
    ? `<div class="cover"><img src="${escHtml(coverUrl)}" /></div>`
    : `<div class="cover-placeholder">${escHtml(entry.title || '')}</div>`

  const infoboxBlock = (entry.infobox && entry.infobox.length)
    ? `<div class="infobox">
        <div class="infobox-header">${escHtml(catMeta.label)}</div>
        ${entry.infobox.map((f, i) => `
          ${i > 0 ? '<div class="infobox-sep"></div>' : ''}
          <div class="infobox-row">
            <span class="infobox-key">${escHtml(f.key)}</span>
            <span class="infobox-val">${renderWiki(f.value)}</span>
          </div>`).join('')}
        <div class="infobox-bottom"></div>
      </div>`
    : ''

  const introBlock = entry.introduction
    ? `<div class="intro">${renderWiki(entry.introduction)}</div>`
    : ''

  const sectionsBlock = (entry.sections || []).map(sec => {
    const imgs = (sec.image_refs || []).map(u =>
      `<img class="sec-img" src="${escHtml(u)}" />`
    ).join('')
    return `
      <div class="section">
        <h3 class="sec-title">${renderWiki(sec.title)}</h3>
        <div class="sec-divider"></div>
        <div class="sec-body">${renderWiki(sec.body)}</div>
        ${imgs}
      </div>`
  }).join('')

  const tagsBlock = (entry.tags && entry.tags.length)
    ? `<div class="tags-divider"></div>
       <div class="tags">${entry.tags.map(t => `<span class="tag">${escHtml(t)}</span>`).join('')}</div>`
    : ''

  return `<!DOCTYPE html>
<html><head><meta charset="utf-8">
<style>
  ${fontBase64 ? `@font-face {
    font-family: 'WQY';
    src: url('${fontBase64}') format('truetype');
    font-weight: normal;
    font-style: normal;
  }` : ''}
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: ${fontBase64 ? "'WQY'," : ''} sans-serif;
    background: #fff;
    width: 375px;
  }
  .card { width: 375px; background: #fff; }

  .topbar {
    height: 48px; display: flex; align-items: center;
    padding: 0 16px; border-bottom: 1px solid #E5E5E5;
  }
  .topbar-back { font-size: 20px; font-weight: 300; color: #1A1A1A; margin-right: 8px; line-height: 1; }
  .topbar-avatar {
    width: 28px; height: 28px; border-radius: 50%; object-fit: cover;
    background: #F5F5F5; flex-shrink: 0;
  }
  .topbar-name { font-size: 14px; font-weight: 600; color: #1A1A1A; margin-left: 8px; }
  .topbar-spacer { flex: 1; }
  .topbar-dots { font-size: 18px; font-weight: 300; color: #1A1A1A; letter-spacing: 2px; }

  .cover img { width: 100%; display: block; }
  .cover-placeholder {
    width: 100%; aspect-ratio: 16/9; display: flex;
    align-items: center; justify-content: center;
    background: linear-gradient(135deg, #f7f7f7, #eee);
    font-size: 14px; color: rgba(0,0,0,0.25); font-weight: 500;
  }

  .content { padding: 20px 16px 0; }
  .title {
    font-family: 'WQY', serif;
    font-size: 24px; font-weight: bold; color: #1A1A1A; line-height: 1.35;
  }
  .subtitle {
    font-size: 14px; color: #666; margin-top: 4px; line-height: 1.45;
  }
  .meta {
    font-size: 12px; color: #999; margin-top: 6px;
  }
  .divider {
    height: 1px; background: #E5E5E5; margin-top: 10px;
  }

  .infobox {
    margin-top: 16px; border-radius: 6px;
    background: #FCFCFC; border: 0.5px solid #F0F0F0;
    overflow: hidden;
  }
  .infobox-header {
    display: flex; align-items: center; gap: 6px;
    padding: 10px 14px;
    font-size: 13px; font-weight: 600; color: #1A1A1A;
  }
  .infobox-sep {
    height: 1px; background: rgba(224,224,224,0.5);
    margin-left: 106px; margin-right: 14px;
  }
  .infobox-row {
    display: flex; align-items: flex-start;
    padding: 5px 14px;
  }
  .infobox-key {
    width: 80px; flex-shrink: 0; text-align: right;
    font-size: 12px; font-weight: 500; color: #999;
    padding-right: 12px; padding-top: 1px;
  }
  .infobox-val {
    flex: 1; font-size: 13px; color: #1A1A1A; line-height: 1.55;
  }
  .infobox-bottom { height: 10px; }

  .intro {
    margin-top: 16px; font-size: 15px; color: #1A1A1A; line-height: 1.8;
  }

  .section { margin-top: 24px; }
  .sec-title {
    font-family: 'WQY', serif;
    font-size: 18px; font-weight: bold; color: #1A1A1A; line-height: 1.45;
  }
  .sec-divider { height: 1px; background: #E5E5E5; margin-top: 2px; }
  .sec-body {
    margin-top: 10px; font-size: 15px; color: #1A1A1A; line-height: 1.8;
  }
  .sec-img {
    width: 100%; border-radius: 8px; margin-top: 10px; display: block;
  }

  .tags-divider { height: 1px; background: #E5E5E5; margin-top: 24px; }
  .tags {
    display: flex; flex-wrap: wrap; gap: 6px;
    padding-top: 14px;
  }
  .tag {
    font-size: 12px; font-style: italic; color: #999;
    border: 0.5px solid #E5E5E5; border-radius: 4px;
    padding: 3px 10px; white-space: nowrap;
  }

  .footer {
    margin-top: 28px; border-top: 1px solid #E5E5E5;
    padding: 24px 20px;
    display: flex; align-items: center; justify-content: space-between;
  }
  .footer-left {
    display: flex; align-items: center; gap: 12px;
  }
  .footer-logo { width: 40px; height: 40px; flex-shrink: 0; }
  .footer-text { display: flex; flex-direction: column; }
  .footer-brand {
    display: flex; align-items: baseline; gap: 5px;
  }
  .footer-brand-en {
    font-family: Georgia, serif;
    font-size: 16px; font-weight: bold; font-style: italic; color: #1A1A1A;
  }
  .footer-brand-cn {
    font-size: 13px; font-weight: 600; color: #1A1A1A;
  }
  .footer-slogan {
    font-size: 11px; color: #999; margin-top: 2px;
  }
  .footer-qr {
    width: 64px; height: 64px; flex-shrink: 0;
    border-radius: 4px;
  }

  .wk-blue { color: #2563EB; text-decoration: underline; text-underline-offset: 2px; }
  .wk-red { color: #DC2626; text-decoration: underline; text-underline-offset: 2px; }
  .wk-src { color: #2563EB; font-size: 10px; }
</style>
</head>
<body>
<div class="card">
  <div class="topbar">
    <span class="topbar-back">‹</span>
    <img class="topbar-avatar" src="${escHtml(avUrl)}" onerror="this.style.display='none'" />
    <span class="topbar-name">${escHtml(entry.author_name)}</span>
    <span class="topbar-spacer"></span>
    <span class="topbar-dots">•••</span>
  </div>
  ${coverBlock}
  <div class="content">
    <div class="title">${renderWiki(entry.title || '未命名词条')}</div>
    ${entry.subtitle ? `<div class="subtitle">${renderWiki(entry.subtitle)}</div>` : ''}
    <div class="meta">${escHtml(catMeta.label)}  ·  ${escHtml(scpMeta.label)}</div>
    <div class="divider"></div>
    ${infoboxBlock}
    ${introBlock}
    ${sectionsBlock}
    ${tagsBlock}
  </div>
  <div class="footer">
    <div class="footer-left">
      ${logoBase64 ? `<img class="footer-logo" src="${logoBase64}" />` : ''}
      <div class="footer-text">
        <div class="footer-brand">
          <span class="footer-brand-en">Lifepedia</span>
          <span class="footer-brand-cn">人间词条</span>
        </div>
        <div class="footer-slogan">一切值得铭记之物，皆可收录</div>
      </div>
    </div>
    ${qrDataURL ? `<img class="footer-qr" src="${qrDataURL}" />` : ''}
  </div>
</div>
</body></html>`
}

// Puppeteer 浏览器实例（进程级复用，断线自动重建）
let browser = null
const pendingCards = new Map()

// 异步任务队列
const renderJobs = new Map() // jobId → { status, url?, error? }

async function getBrowser() {
  if (browser && browser.connected) return browser
  if (browser) { try { await browser.close() } catch {} browser = null }
  browser = await puppeteer.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
      '--no-first-run',
      '--no-zygote',
    ],
  })
  browser.on('disconnected', () => { browser = null })
  return browser
}

// 带自动重试的截图函数
async function renderCard(html, port, retries = 2) {
  const token = Math.random().toString(36).slice(2)
  pendingCards.set(token, html)
  const cardUrl = `http://127.0.0.1:${port}/api/_card/${token}`
  let lastErr
  for (let attempt = 0; attempt <= retries; attempt++) {
    const t = Date.now()
    const ms = () => `${Date.now() - t}ms`
    let page
    try {
      const b = await getBrowser()
      console.log(`  [render#${attempt+1}] getBrowser ${ms()}`)
      page = await b.newPage()
      await page.setViewport({ width: 375, height: 800, deviceScaleFactor: 3 })
      await page.goto(cardUrl, { waitUntil: 'domcontentloaded', timeout: 15000 })
      console.log(`  [render#${attempt+1}] goto ${ms()}`)
      await Promise.all([
        Promise.race([
          page.evaluate(() => document.fonts.ready),
          new Promise(r => setTimeout(r, 6000)),
        ]),
        Promise.race([
          page.evaluate(() =>
            Promise.all(
              Array.from(document.images).map(img =>
                img.complete ? Promise.resolve() :
                new Promise(r => { img.onload = r; img.onerror = r })
              )
            )
          ),
          new Promise(r => setTimeout(r, 5000)),
        ]),
      ])
      console.log(`  [render#${attempt+1}] 字体+图片 ${ms()}`)
      await new Promise(r => setTimeout(r, 200))
      const card = await page.$('.card')
      if (!card) throw new Error('.card element not found')
      const screenshot = await card.screenshot({ type: 'png', omitBackground: false })
      console.log(`  [render#${attempt+1}] screenshot ${ms()}`)
      await page.close().catch(() => {})
      return screenshot
    } catch (err) {
      lastErr = err
      console.error(`  [render#${attempt+1}] 失败 ${ms()}:`, err.message)
      if (page) await page.close().catch(() => {})
      if (browser && !browser.connected) { try { await browser.close() } catch {} browser = null }
      if (attempt < retries) await new Promise(r => setTimeout(r, 1200 * (attempt + 1)))
    }
  }
  throw lastErr
}

const app = express()

// 手动解析 JSON body（绕开 Express 5 express.json() 卡死问题）
app.use((req, res, next) => {
  if (req.method === 'GET' || req.method === 'HEAD') return next()
  const ct = req.headers['content-type'] || ''
  if (!ct.includes('application/json')) return next()
  let raw = ''
  req.setEncoding('utf8')
  req.on('data', chunk => { raw += chunk })
  req.on('end', () => {
    try { req.body = JSON.parse(raw) } catch { req.body = {} }
    next()
  })
  req.on('error', () => { req.body = {}; next() })
})

app.get('/api/_card/:token', (req, res) => {
  const html = pendingCards.get(req.params.token)
  if (!html) return res.status(404).send('expired')
  res.set('Content-Type', 'text/html; charset=utf-8')
  res.send(html)
})

// 提交生成任务，立即返回 jobId，后台异步执行
app.post('/api/render-share', (req, res) => {
  const { entry } = req.body
  if (!entry) return res.status(400).json({ error: 'missing entry' })

  const jobId = Math.random().toString(36).slice(2)
  renderJobs.set(jobId, { status: 'pending' })
  res.json({ jobId })

  // 后台执行，不阻塞响应
  ;(async () => {
    const t0 = Date.now()
    const elapsed = () => `+${((Date.now() - t0) / 1000).toFixed(1)}s`
    console.log(`[${jobId}] 开始生成`)
    try {
      const entryURL = 'https://overlordkim.github.io/lifepedia-redirect/'
      const qrDataURL = await QRCode.toDataURL(entryURL, {
        width: 256, margin: 1, color: { dark: '#1A1A1A', light: '#FFFFFF' }
      })
      console.log(`[${jobId}] QR 生成完 ${elapsed()}`)
      const html = buildCardHTML(entry, qrDataURL)
      console.log(`[${jobId}] HTML 生成完 ${elapsed()}`)
      const screenshot = await renderCard(html, PORT)
      console.log(`[${jobId}] 截图完 ${elapsed()} (${Math.round(screenshot.length/1024)}KB)`)
      const url = await uploadShareImage(screenshot)
      console.log(`[${jobId}] 上传完 ${elapsed()} → ${url}`)
      renderJobs.set(jobId, { status: 'done', url })
    } catch (err) {
      console.error(`[${jobId}] 失败 ${elapsed()} →`, err.message)
      renderJobs.set(jobId, { status: 'error', error: err.message })
    }
    setTimeout(() => renderJobs.delete(jobId), 10 * 60 * 1000)
  })()
})

// 查询任务状态
app.get('/api/render-status/:jobId', (req, res) => {
  const job = renderJobs.get(req.params.jobId)
  if (!job) return res.status(404).json({ error: 'job not found' })
  res.json(job)
})

app.use(express.static(path.join(__dirname, 'pwa', 'dist'), {
  setHeaders(res) {
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate')
  }
}))

app.use((req, res, next) => {
  if (req.method === 'GET' && !req.path.startsWith('/api/')) {
    res.sendFile(path.join(__dirname, 'pwa', 'dist', 'index.html'))
  } else {
    next()
  }
})

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://localhost:${PORT}`)
})

process.on('SIGINT', async () => {
  if (browser) await browser.close()
  process.exit(0)
})
