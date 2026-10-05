// Opens the live site straight into Riyadh at a few points of the flight,
// waits for the tiles to stream, and saves screenshots and console output.
const { chromium } = require('playwright')
const fs = require('fs')

const site = process.env.SITE.replace(/\/?$/, '/')
const points = ['0.5', '0.56', '0.62']
fs.mkdirSync('checks', { recursive: true })

;(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] })
  const page = await browser.newPage({ viewport: { width: 960, height: 540 } })
  const log = []
  page.on('console', (m) => log.push(`${m.type()}: ${m.text().slice(0, 300)}`))
  page.on('pageerror', (e) => log.push(`pageerror: ${e.message}`))
  page.on('response', async (r) => {
    if (r.url().includes('tile.googleapis.com') && r.status() >= 400) {
      // Google's error text says why a key is refused (API not enabled, referrer, billing).
      let body = ''
      try {
        body = (await r.text()).replace(/\s+/g, ' ').slice(0, 600)
      } catch {}
      log.push(`tiles ${r.status()} ${new URL(r.url()).pathname} ${body}`)
    }
  })
  let tileRequests = 0
  page.on('request', (r) => {
    if (r.url().includes('tile.googleapis.com')) tileRequests++
  })
  for (const p of points) {
    await page.goto(`${site}?city=riyadh&lite&debug&p=${p}`, { waitUntil: 'load', timeout: 120000 })
    await page.waitForTimeout(45000)
    await page.screenshot({ path: `checks/riyadh-p${p}.png`, timeout: 600000 })
  }
  // Never record the key itself.
  const clean = log.map((l) => l.replace(/key=[A-Za-z0-9_-]+/g, 'key=…'))
  fs.writeFileSync('checks/console.txt', `site: ${site}\ntile requests: ${tileRequests}\n\n${[...new Set(clean)].join('\n')}\n`)
  await browser.close()
})()
