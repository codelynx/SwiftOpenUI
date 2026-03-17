// Capture screenshots of all Wasm examples using Puppeteer.
// Requires: npm install, examples built via ./build-wasm.sh, vite server running.
//
// Usage:
//   cd web && npm run screenshot
//   (make sure `npx vite` is running in another terminal)

import puppeteer from 'puppeteer'
import { mkdirSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const outDir = resolve(__dirname, '../screenshots/web')
mkdirSync(outDir, { recursive: true })

const BASE_URL = process.env.BASE_URL || 'http://localhost:3000'

const examples = [
    { name: '01-HelloWorld', path: '/examples/HelloWorld.html' },
    { name: '02-TextStyles', path: '/examples/TextStyles.html' },
    { name: '03-Buttons', path: '/examples/Buttons.html' },
    { name: '04-State', path: '/examples/StateDemo.html' },
    { name: '05-Layout', path: '/examples/Layout.html' },
]

async function main() {
    const browser = await puppeteer.launch({
        headless: true,
        executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        args: ['--no-sandbox'],
    })

    for (const example of examples) {
        const page = await browser.newPage()
        await page.setViewport({ width: 800, height: 600, deviceScaleFactor: 2 })

        console.log(`Capturing ${example.name}...`)
        try {
            await page.goto(`${BASE_URL}${example.path}`, {
                waitUntil: 'networkidle0',
                timeout: 30000,
            })
            // Wait for Wasm to initialize and render
            await page.waitForFunction(() => document.body.children.length > 0, { timeout: 15000 })
            await new Promise(r => setTimeout(r, 2000))

            const outFile = resolve(outDir, `${example.name}.png`)
            await page.screenshot({ path: outFile, fullPage: true })
            console.log(`  Saved: ${outFile}`)
        } catch (e) {
            console.log(`  Warning: ${e.message}`)
        }
        await page.close()
    }

    await browser.close()
    console.log(`\nAll screenshots saved to ${outDir}/`)
}

main()
