import express from 'express'
import puppeteer from 'puppeteer'
import QRCode from 'qrcode'
import path from 'path'
import fs from 'fs'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const PORT = parseInt(process.env.PORT || '17497', 10)

const SUPABASE_URL = 'https://okoeauotvsgjwhydfgsk.supabase.co'

function avatarURL(userId) {
  return `${SUPABASE_URL}/storage/v1/object/public/images/avatars/${userId}.jpg`
}

const logoBase64 = (() => {
  const p = path.join(__dirname, 'logo_transparent.png')
  if (fs.existsSync(p)) return 'data:image/png;base64,' + fs.readFileSync(p).toString('base64')
  return ''
})()

const CATEGORY_META = {
  person:    { label: '人物', emoji: '👤' },
  place:     { label: '栖居', emoji: '🏠' },
  companion: { label: '相伴', emoji: '🐾' },
  taste:     { label: '滋味', emoji: '🍜' },
  keepsake:  { label: '旧物', emoji: '📦' },
  moment:    { label: '际遇', emoji: '⚡' },
  era:       { label: '流年', emoji: '⏳' },
}

const SCOPE_META = {
  private:       { label: '私人', emoji: '🔒' },
  collaborative: { label: '合编', emoji: '👥' },
  public:        { label: '公共', emoji: '🌐' },
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
        <div class="infobox-header">${catMeta.emoji} ${escHtml(catMeta.label)}</div>
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
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
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
    font-family: Georgia, "Times New Roman", serif;
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
    font-family: Georgia, "Times New Roman", serif;
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
    font-family: Georgia, "Times New Roman", serif;
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
    <div class="meta">${catMeta.emoji} ${escHtml(catMeta.label)}  ·  ${scpMeta.emoji} ${escHtml(scpMeta.label)}</div>
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
        <div class="footer-slogan">你的生命值得一座百科</div>
      </div>
    </div>
    ${qrDataURL ? `<img class="footer-qr" src="${qrDataURL}" />` : ''}
  </div>
</div>
</body></html>`
}

let browser = null
const pendingCards = new Map()

async function getBrowser() {
  if (!browser) {
    browser = await puppeteer.launch({
      headless: 'new',
      args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
    })
  }
  return browser
}

const app = express()
app.use(express.json({ limit: '5mb' }))

app.get('/api/_card/:token', (req, res) => {
  const html = pendingCards.get(req.params.token)
  if (!html) return res.status(404).send('expired')
  res.set('Content-Type', 'text/html; charset=utf-8')
  res.send(html)
})

app.post('/api/render-share', async (req, res) => {
  const { entry } = req.body
  if (!entry) return res.status(400).json({ error: 'missing entry' })

  const token = Math.random().toString(36).slice(2)
  let page
  try {
    const entryURL = 'https://lifepedia.a.pinggy.link'
    const qrDataURL = await QRCode.toDataURL(entryURL, {
      width: 256, margin: 1, color: { dark: '#1A1A1A', light: '#FFFFFF' }
    })
    const html = buildCardHTML(entry, qrDataURL)
    pendingCards.set(token, html)

    const b = await getBrowser()
    page = await b.newPage()
    await page.setViewport({ width: 375, height: 800, deviceScaleFactor: 3 })

    page.on('requestfailed', r =>
      console.log('  [img fail]', r.url().slice(0, 80), r.failure()?.errorText)
    )

    const cardUrl = `http://127.0.0.1:${PORT}/api/_card/${token}`
    await page.goto(cardUrl, { waitUntil: 'networkidle0', timeout: 30000 })

    await page.evaluate(() =>
      Promise.all(Array.from(document.images).map(img =>
        img.complete ? Promise.resolve() :
        new Promise(r => { img.onload = r; img.onerror = r })
      ))
    )

    const card = await page.$('.card')
    const screenshot = await card.screenshot({ type: 'png', omitBackground: false })

    res.set('Content-Type', 'image/png')
    res.set('Cache-Control', 'no-store')
    res.send(screenshot)
  } catch (err) {
    console.error('render-share error:', err)
    res.status(500).json({ error: err.message })
  } finally {
    pendingCards.delete(token)
    if (page) await page.close().catch(() => {})
  }
})

app.use(express.static(path.join(__dirname, 'pwa', 'dist'), {
  setHeaders(res, filePath) {
    if (filePath.endsWith('.html') || filePath.endsWith('sw.js') || filePath.endsWith('registerSW.js')) {
      res.set('Cache-Control', 'no-store')
    }
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
