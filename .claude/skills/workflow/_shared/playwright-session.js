#!/usr/bin/env node
/**
 * playwright-session.js — Session-Isolated Browser Manager for wf-fix-bugs
 *
 * Moi session co browser rieng biet qua --remote-debugging-port + --user-data-dir.
 * Browser duoc launch nhu detached child process → ton tai doc lap voi Node.js process.
 * Cac probe goi CLI actions: launch, navigate, snapshot, evaluate, click, type, close, ...
 *
 * Usage:
 *   node playwright-session.js --session-dir=<path> --action=<action> [options...]
 *
 * Actions:
 *   launch      Khoi tao browser instance (goi 1 lan khi bat dau session)
 *   close       Dong browser + don user-data-dir
 *   status      Kiem tra browser con song khong
 *   navigate    Dieu huong toi URL → { url, title, status }
 *   snapshot    Lay accessibility snapshot → { snapshot: "..." }
 *   screenshot  Chup anh trang → { path: "..." }
 *   evaluate    Thuc thi JavaScript trong page → { result }
 *   click       Click vao element → { clicked, url, title }
 *   type        Nhap text vao element → { filled }
 *   console     Lay collected console errors → { errors: [...] }
 *   network     Lay collected network failures (status >= 400) → { failures: [...] }
 *   wait        Doi time hoac selector → { waited }
 *   tabs        Xem danh sach pages/tabs → { tabs: [...] }
 *   back        Quay lai trang truoc → { url, title }
 *   dialog      Xu ly dialog → { handled }
 *   select      Chon option trong dropdown → { selected }
 *   fill_form   Dien nhieu field cung luc → { filled }
 *   hover       Hover vao element → { hovered }
 *   press_key   Nhan phim → { pressed }
 *   upload_file Upload file → { uploaded }
 *   resize      Thay doi viewport size → { resized }
 *
 *   navigate_parallel  [W2.1] Mo N contexts trong cung 1 browser, navigate parallel
 *                      (max MCV3_PW_MAX_CONTEXTS=4 default). Args:
 *                        --routes-json='["/r1","/r2",...]'
 *                        --base-url=http://localhost:3000
 *                        --evidence-dir=$SESSION_DIR/phase5-verify/evidence
 *                        [--wait-until=networkidle] [--timeout=15000]
 *                      Capture per-route evidence: console-{slug}.txt, snapshot-{slug}.yml,
 *                      screenshot-{slug}.png. Output JSON: { status, max_contexts, results[] }.
 *   close_context     [W2.1] Cleanup contexts da tao boi navigate_parallel (idempotent).
 *                      Args: [--close-all=true]
 *
 * Environment variables:
 *   MCV3_PW_MAX_CONTEXTS  Default 4. Set =1 de force sequential (escape hatch).
 *                         Hard cap 8 trong code de chong OOM.
 */

const { chromium, devices } = require('playwright');
const { spawn } = require('child_process');
const fs = require('fs');
const net = require('net');
const path = require('path');
const http = require('http');

// ── CLI Argument Parsing ────────────────────────────────────────────────

function parseArgs() {
  const args = {};
  const positional = [];
  for (let i = 2; i < process.argv.length; i++) {
    const arg = process.argv[i];
    if (arg.startsWith('--')) {
      const eq = arg.indexOf('=');
      if (eq >= 0) {
        args[arg.slice(2, eq)] = arg.slice(eq + 1);
      } else {
        args[arg.slice(2)] = process.argv[++i] || 'true';
      }
    } else {
      positional.push(arg);
    }
  }
  args._ = positional;
  return args;
}

function fail(msg, code = 1) {
  console.error(JSON.stringify({ error: msg }));
  process.exit(code);
}

// ── Port Utilities ──────────────────────────────────────────────────────

function getSessionPort(sessionDir) {
  const sessionId = path.basename(sessionDir);
  let hash = 0;
  for (let i = 0; i < sessionId.length; i++) {
    hash = ((hash << 5) - hash) + sessionId.charCodeAt(i);
    hash |= 0; // Convert to 32bit integer
  }
  const basePort = 9323;
  return basePort + (Math.abs(hash) % 1000);
}

// v10.2 — Probe TCP port liveness. Resolves true nếu port BUSY (đang có process listen).
function isPortBusy(port, host = '127.0.0.1', timeoutMs = 200) {
  return new Promise((resolve) => {
    const tester = net.createServer()
      .once('error', (err) => {
        // EADDRINUSE → port đang busy
        if (err.code === 'EADDRINUSE') resolve(true);
        else resolve(false); // Lỗi khác (EACCES) — coi như free để tránh false-busy
      })
      .once('listening', () => {
        tester.close(() => resolve(false));
      })
      .listen(port, host);
    setTimeout(() => {
      try { tester.close(); } catch {}
      resolve(false);
    }, timeoutMs);
  });
}

// v10.2 — Tìm free port bắt đầu từ candidate, tăng dần. Max 50 tries → throw E044.
async function findFreePort(candidatePort, maxTries = 50) {
  let port = candidatePort;
  for (let i = 0; i < maxTries; i++) {
    const busy = await isPortBusy(port);
    if (!busy) return port;
    port = port + 1;
    // Tránh tràn khỏi range hợp lý (9323..14322) — wrap về base
    if (port > 14322) port = 9323;
  }
  throw new Error(`E044: No free port found in range ${candidatePort}..${candidatePort + maxTries}`);
}

function httpGet(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch { resolve(data); }
      });
    }).on('error', reject);
  });
}

// ── Action: launch ──────────────────────────────────────────────────────

async function actionLaunch(port, userDataDir, sessionFile, launchOpts = {}) {
  // v10.2 — Đọc cờ từ launchOpts: showBrowser (visible), mobileMode, deviceName
  const showBrowser = launchOpts.showBrowser === true;
  const mobileMode = launchOpts.mobileMode === true;
  const deviceName = launchOpts.deviceName || 'iPhone 14';

  // Check if already running
  if (fs.existsSync(sessionFile)) {
    try {
      const existing = JSON.parse(fs.readFileSync(sessionFile, 'utf-8'));
      const check = await httpGet(`http://127.0.0.1:${existing.port}/json/version`);
      if (check && check.webSocketDebuggerUrl) {
        console.log(JSON.stringify({ status: 'already_running', ...existing }));
        return;
      }
    } catch {
      // Stale session file — will re-launch
      fs.unlinkSync(sessionFile);
    }
  }

  // v10.2 — Port retry: candidate có thể bị chiếm bởi session khác (hash collision) → tìm free port
  let resolvedPort;
  try {
    resolvedPort = await findFreePort(port);
  } catch (e) {
    fail(`E044: ${e.message}`);
  }
  if (resolvedPort !== port) {
    console.error(`INFO: Port ${port} busy, using free port ${resolvedPort}`);
  }

  // Find chromium executable
  const executablePath = chromium.executablePath();

  // v10.2 — Conditional headless: chỉ headless khi KHÔNG show-browser
  const launchArgs = [
    `--remote-debugging-port=${resolvedPort}`,
    `--user-data-dir=${userDataDir}`,
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-dev-shm-usage'
  ];
  if (!showBrowser) {
    launchArgs.unshift('--headless=new');
    launchArgs.push('--disable-gpu');  // GPU disable chỉ áp dụng headless mode
  }
  // Mobile mode dùng device viewport — set sau khi connect (không qua CLI args)

  // Launch chromium as detached child process
  const child = spawn(executablePath, launchArgs, {
    detached: true,
    stdio: 'ignore',
    windowsHide: !showBrowser  // Visible mode KHÔNG hide window
  });
  child.unref();

  // Poll until browser is ready (max 15s)
  const deadline = Date.now() + 15000;
  let wsEndpoint = null;
  let lastError = null;

  while (Date.now() < deadline) {
    await new Promise(r => setTimeout(r, 500));
    try {
      const info = await httpGet(`http://127.0.0.1:${resolvedPort}/json/version`);
      if (info && info.webSocketDebuggerUrl) {
        wsEndpoint = info.webSocketDebuggerUrl;
        break;
      }
    } catch (e) {
      lastError = e.message;
    }
  }

  if (!wsEndpoint) {
    // Kill the spawned browser on failure
    try { process.kill(-child.pid, 'SIGTERM'); } catch {}
    fail(`Browser launch timeout after 15s. Last error: ${lastError}`);
  }

  // v10.2 — Validate device name nếu mobile mode
  let deviceConfig = null;
  if (mobileMode) {
    deviceConfig = devices[deviceName];
    if (!deviceConfig) {
      console.error(`WARN: Unknown device '${deviceName}' — fallback to 'iPhone 14'`);
      deviceConfig = devices['iPhone 14'] || null;
    }
  }

  // Verify connectivity via Playwright
  let browser;
  try {
    browser = await chromium.connectOverCDP(wsEndpoint);
    const pages = browser.contexts()[0]?.pages() || [];
    const page = pages[0] || await browser.contexts()[0]?.newPage();

    // v10.2 — Apply mobile viewport via CDP nếu mobile mode
    if (deviceConfig && page) {
      try {
        await page.setViewportSize({
          width: deviceConfig.viewport.width,
          height: deviceConfig.viewport.height
        });
        const cdp = await page.context().newCDPSession(page);
        await cdp.send('Emulation.setUserAgentOverride', {
          userAgent: deviceConfig.userAgent
        });
        await cdp.send('Emulation.setDeviceMetricsOverride', {
          width: deviceConfig.viewport.width,
          height: deviceConfig.viewport.height,
          deviceScaleFactor: deviceConfig.deviceScaleFactor || 1,
          mobile: deviceConfig.isMobile || false
        });
      } catch (emuErr) {
        console.error(`WARN: Mobile emulation partial failure: ${emuErr.message}`);
      }
    }

    const state = {
      status: 'launched',
      port: resolvedPort,
      wsEndpoint,
      userDataDir,
      pid: child.pid,
      launchedAt: new Date().toISOString(),
      pageCount: pages.length,
      mode: showBrowser ? 'visible' : 'headless',
      mobile: mobileMode,
      device: mobileMode ? deviceName : null,
      viewport: deviceConfig ? deviceConfig.viewport : null
    };

    fs.writeFileSync(sessionFile, JSON.stringify(state, null, 2));
    console.log(JSON.stringify(state));
  } catch (e) {
    try { process.kill(-child.pid, 'SIGTERM'); } catch {}
    fail(`Browser connection failed: ${e.message}`);
  } finally {
    if (browser) await browser.close().catch(() => {});
  }
}

// ── Action: close ───────────────────────────────────────────────────────

async function actionClose(sessionFile) {
  if (!fs.existsSync(sessionFile)) {
    console.log(JSON.stringify({ status: 'not_running' }));
    return;
  }

  const state = JSON.parse(fs.readFileSync(sessionFile, 'utf-8'));

  // Connect and close
  try {
    const browser = await chromium.connectOverCDP(state.wsEndpoint);
    await browser.close().catch(() => {});
  } catch {}

  // Kill the detached browser process
  try {
    process.kill(-state.pid, 'SIGTERM');
  } catch {}

  // Clean up session file
  fs.unlinkSync(sessionFile);

  // Clean up user data dir (async, don't wait)
  const { exec } = require('child_process');
  exec(`rm -rf "${state.userDataDir}" 2>/dev/null || rmdir /s /q "${state.userDataDir}" 2>nul`);

  console.log(JSON.stringify({ status: 'closed', port: state.port }));
}

// ── Action: status ──────────────────────────────────────────────────────

async function actionStatus(sessionFile) {
  if (!fs.existsSync(sessionFile)) {
    console.log(JSON.stringify({ status: 'not_launched' }));
    return;
  }

  const state = JSON.parse(fs.readFileSync(sessionFile, 'utf-8'));
  try {
    const info = await httpGet(`http://127.0.0.1:${state.port}/json/version`);
    if (info && info.webSocketDebuggerUrl) {
      try {
        const browser = await chromium.connectOverCDP(state.wsEndpoint);
        const pages = [];
        for (const ctx of browser.contexts()) {
          for (const p of ctx.pages()) {
            pages.push({ url: p.url(), title: await p.title().catch(() => '') });
          }
        }
        await browser.close().catch(() => {});
        console.log(JSON.stringify({ status: 'running', pages, port: state.port, launchedAt: state.launchedAt }));
      } catch {
        console.log(JSON.stringify({ status: 'running', port: state.port, launchedAt: state.launchedAt }));
      }
    } else {
      console.log(JSON.stringify({ status: 'unresponsive', port: state.port }));
    }
  } catch {
    console.log(JSON.stringify({ status: 'dead', port: state.port }));
  }
}

// ── Action: navigate_parallel ───────────────────────────────────────────
//
// W2.1 (plan wf-fix-bugs-v10-speedup): mo N contexts trong cung 1 browser
// instance, navigate parallel. Max concurrency = MCV3_PW_MAX_CONTEXTS (default 4).
// Moi context capture console errors + screenshot + snapshot doc lap → ghi
// per-route evidence vao --evidence-dir. Auth-required routes nen sequential
// (caller responsibility — script chi handle routes nhan duoc).
//
// Args:
//   --routes-json=<json-array>   ['/route1', '/route2', ...]
//   --base-url=<url>             Prefix duoc nguoi goi pass (vd http://localhost:3000)
//   --evidence-dir=<path>        Thu muc luu evidence per route
//   --wait-until=<state>         (default networkidle)
//   --timeout=<ms>               (default 15000)
//
// Output JSON:
//   {
//     status: 'ok' | 'partial' | 'error',
//     max_contexts: N,
//     total_routes: N,
//     results: [
//       { route, slug, status: 'ok'|'error', url, title, error?,
//         console_errors: N, page_errors: N, network_failures: N,
//         evidence: { console, snapshot, screenshot } }
//     ]
//   }

function slugifyRoute(route) {
  return String(route)
    .replace(/^https?:\/\/[^/]+/i, '')
    .replace(/[^a-zA-Z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase() || 'root';
}

function getMaxContexts() {
  const envVal = process.env.MCV3_PW_MAX_CONTEXTS;
  if (!envVal) return 4;
  const n = parseInt(envVal, 10);
  if (!Number.isFinite(n) || n < 1) return 4;
  return Math.min(n, 8); // hard cap 8 de chong OOM
}

async function actionNavigateParallel(sessionFile, params) {
  if (!fs.existsSync(sessionFile)) {
    fail('Browser not launched. Run action=launch first.');
  }

  const routesJson = params['routes-json'] || fail('--routes-json is required (JSON array)');
  let routes;
  try {
    routes = JSON.parse(routesJson);
    if (!Array.isArray(routes) || routes.length === 0) {
      fail('--routes-json must be non-empty JSON array');
    }
  } catch (e) {
    fail(`--routes-json parse error: ${e.message}`);
  }

  const baseUrl = params['base-url'] || '';
  const evidenceDir = params['evidence-dir'] || fail('--evidence-dir is required');
  const waitUntil = params['wait-until'] || 'networkidle';
  const timeout = parseInt(params.timeout) || 15000;
  const maxContexts = getMaxContexts();

  if (!fs.existsSync(evidenceDir)) {
    fs.mkdirSync(evidenceDir, { recursive: true });
  }

  const state = JSON.parse(fs.readFileSync(sessionFile, 'utf-8'));
  let browser;
  try {
    browser = await chromium.connectOverCDP(state.wsEndpoint);
  } catch (e) {
    fail(`Cannot connect to browser at port ${state.port}: ${e.message}`);
  }

  // Concurrency limiter — process routes trong batches max maxContexts
  const results = [];
  const batches = [];
  for (let i = 0; i < routes.length; i += maxContexts) {
    batches.push(routes.slice(i, i + maxContexts));
  }

  try {
    for (const batch of batches) {
      const batchResults = await Promise.all(batch.map(async (route) => {
        const slug = slugifyRoute(route);
        const fullUrl = baseUrl ? `${baseUrl.replace(/\/$/, '')}${route.startsWith('/') ? route : '/' + route}` : route;
        const consolePath = path.join(evidenceDir, `console-${slug}.txt`);
        const snapshotPath = path.join(evidenceDir, `snapshot-${slug}.yml`);
        const screenshotPath = path.join(evidenceDir, `screenshot-${slug}.png`);

        let context;
        let page;
        const consoleErrors = [];
        const pageErrors = [];
        const networkFailures = [];

        try {
          // 1 context per route → isolated cookies, storage, console
          context = await browser.newContext();
          page = await context.newPage();

          // Listeners cho console + network + page errors (truoc khi navigate)
          page.on('console', msg => {
            if (msg.type() === 'error') {
              consoleErrors.push({
                text: (msg.text() || '').substring(0, 500),
                location: msg.location ? msg.location() : null,
                timestamp: new Date().toISOString()
              });
            }
          });
          page.on('pageerror', err => {
            pageErrors.push({
              message: (err.message || '').substring(0, 500),
              timestamp: new Date().toISOString()
            });
          });
          page.on('response', resp => {
            if (resp.status() >= 400) {
              networkFailures.push({
                url: resp.url(),
                status: resp.status(),
                method: resp.request().method(),
                timestamp: new Date().toISOString()
              });
            }
          });

          // Navigate
          let navError = null;
          let pageUrl = fullUrl;
          let title = '';
          try {
            await page.goto(fullUrl, { waitUntil, timeout });
            pageUrl = page.url();
            title = await page.title().catch(() => '');
          } catch (e) {
            navError = (e.message || '').substring(0, 500);
          }

          // Capture evidence (per route, isolated tu context khac)
          // console-{slug}.txt
          const consoleLines = consoleErrors.map(e => `[${e.timestamp}] ERROR: ${e.text}`).join('\n');
          const pageErrorLines = pageErrors.map(e => `[${e.timestamp}] PAGE_ERROR: ${e.message}`).join('\n');
          const networkLines = networkFailures.map(f => `[${f.timestamp}] NET ${f.status} ${f.method} ${f.url}`).join('\n');
          fs.writeFileSync(consolePath, [
            `# Route: ${route}`,
            `# URL: ${pageUrl}`,
            `# Navigated: ${navError ? 'FAIL: ' + navError : 'OK'}`,
            '',
            '## Console errors',
            consoleLines || '(none)',
            '',
            '## Page errors',
            pageErrorLines || '(none)',
            '',
            '## Network failures',
            networkLines || '(none)'
          ].join('\n'));

          // snapshot-{slug}.yml (accessibility tree + minimal DOM info)
          let snapshotYaml = `route: ${route}\nurl: ${pageUrl}\ntitle: ${JSON.stringify(title)}\n`;
          if (!navError) {
            try {
              const accSnapshot = await page.accessibility.snapshot({ interestingOnly: false }).catch(() => null);
              if (accSnapshot) {
                snapshotYaml += `accessibility_root_role: ${accSnapshot.role || 'unknown'}\n`;
                snapshotYaml += `accessibility_root_name: ${JSON.stringify(accSnapshot.name || '')}\n`;
              }
              const domInfo = await page.evaluate(() => ({
                nodeCount: document.querySelectorAll('*').length,
                linkCount: document.querySelectorAll('a[href]').length,
                buttonCount: document.querySelectorAll('button, [role="button"]').length,
                formCount: document.querySelectorAll('form').length
              })).catch(() => ({}));
              snapshotYaml += `dom:\n`;
              snapshotYaml += `  node_count: ${domInfo.nodeCount || 0}\n`;
              snapshotYaml += `  link_count: ${domInfo.linkCount || 0}\n`;
              snapshotYaml += `  button_count: ${domInfo.buttonCount || 0}\n`;
              snapshotYaml += `  form_count: ${domInfo.formCount || 0}\n`;
            } catch (e) {
              snapshotYaml += `snapshot_error: ${JSON.stringify((e.message || '').substring(0, 200))}\n`;
            }
          }
          fs.writeFileSync(snapshotPath, snapshotYaml);

          // screenshot-{slug}.png (only if nav succeeded)
          if (!navError) {
            try {
              await page.screenshot({ path: screenshotPath, fullPage: false, type: 'png' });
            } catch (e) {
              // Screenshot loi khong fail toan route
            }
          }

          return {
            route,
            slug,
            status: navError ? 'error' : 'ok',
            url: pageUrl,
            title,
            error: navError,
            console_errors: consoleErrors.length,
            page_errors: pageErrors.length,
            network_failures: networkFailures.length,
            evidence: {
              console: consolePath,
              snapshot: snapshotPath,
              screenshot: navError ? null : screenshotPath
            }
          };
        } catch (e) {
          return {
            route,
            slug,
            status: 'error',
            error: (e.message || '').substring(0, 500),
            console_errors: 0,
            page_errors: 0,
            network_failures: 0,
            evidence: { console: null, snapshot: null, screenshot: null }
          };
        } finally {
          if (context) await context.close().catch(() => {});
        }
      }));
      results.push(...batchResults);
    }

    const errorCount = results.filter(r => r.status === 'error').length;
    const overallStatus = errorCount === 0 ? 'ok' : (errorCount === results.length ? 'error' : 'partial');

    console.log(JSON.stringify({
      status: overallStatus,
      max_contexts: maxContexts,
      total_routes: routes.length,
      results
    }));
  } finally {
    if (browser) await browser.close().catch(() => {});
  }
}

// ── Action: close_context ───────────────────────────────────────────────
//
// W2.1: Dong specific context theo wsEndpoint cua context (neu nguoi goi
// luu lai). Hien tai navigate_parallel da auto-close context sau khi capture
// evidence, nen close_context la op TIEN ICH (idempotent no-op khi khong
// con context active). Cung pho thong de cleanup neu caller can hard reset.
//
// Args:
//   --close-all=true  Dong TAT CA contexts (tru default context dau)

async function actionCloseContext(sessionFile, params) {
  if (!fs.existsSync(sessionFile)) {
    console.log(JSON.stringify({ status: 'not_launched', closed: 0 }));
    return;
  }

  const closeAll = params['close-all'] === 'true' || params['close-all'] === true;
  const state = JSON.parse(fs.readFileSync(sessionFile, 'utf-8'));

  let browser;
  try {
    browser = await chromium.connectOverCDP(state.wsEndpoint);
  } catch (e) {
    console.log(JSON.stringify({ status: 'connect_failed', closed: 0, error: e.message }));
    return;
  }

  let closed = 0;
  try {
    const contexts = browser.contexts();
    // Skip context[0] (default — tranh kill connection chinh)
    const toClose = closeAll ? contexts.slice(1) : [];
    for (const ctx of toClose) {
      try {
        await ctx.close();
        closed++;
      } catch {}
    }
    console.log(JSON.stringify({
      status: 'ok',
      closed,
      remaining_contexts: browser.contexts().length
    }));
  } finally {
    if (browser) await browser.close().catch(() => {});
  }
}

// ── Connect helper ──────────────────────────────────────────────────────

async function connectAndAct(sessionFile, actionFn, params) {
  if (!fs.existsSync(sessionFile)) {
    fail('Browser not launched. Run action=launch first.');
  }

  const state = JSON.parse(fs.readFileSync(sessionFile, 'utf-8'));
  let browser;
  try {
    browser = await chromium.connectOverCDP(state.wsEndpoint);
  } catch (e) {
    fail(`Cannot connect to browser at port ${state.port}: ${e.message}`);
  }

  try {
    const contexts = browser.contexts();
    const context = contexts[0] || await browser.newContext();
    const pages = context.pages();
    const page = pages[0] || await context.newPage();

    if (!pages.length) {
      state.pageCount = 1;
      fs.writeFileSync(sessionFile, JSON.stringify(state, null, 2));
    }

    const result = await actionFn(page, params, context, state);
    console.log(JSON.stringify(result));
  } finally {
    await browser.close().catch(() => {});
  }
}

// ── Individual Actions ──────────────────────────────────────────────────

async function runNavigate(page, params) {
  const url = params.url || fail('--url is required for navigate');
  const waitUntil = params['wait-until'] || 'domcontentloaded';
  const timeout = parseInt(params.timeout) || 15000;

  // Inject error listeners before navigating
  const listenersInjected = await page.evaluate(() => {
    if (!window.__MCV3_BROWSER_MONITOR__) {
      window.__MCV3_BROWSER_MONITOR__ = { consoleErrors: [], networkFailures: [], pageErrors: [] };
      window.addEventListener('error', (e) => {
        window.__MCV3_BROWSER_MONITOR__.pageErrors.push({
          message: e.message?.substring(0, 500) || 'Unknown',
          source: e.filename || '',
          line: e.lineno || 0,
          col: e.colno || 0,
          url: window.location.href,
          timestamp: new Date().toISOString()
        });
      });
      window.addEventListener('unhandledrejection', (e) => {
        window.__MCV3_BROWSER_MONITOR__.pageErrors.push({
          message: (e.reason?.message || String(e.reason)).substring(0, 500),
          url: window.location.href,
          timestamp: new Date().toISOString(),
          unhandledRejection: true
        });
      });
    }
    return true;
  }).catch(() => true);

  try {
    await page.goto(url, { waitUntil, timeout });
    return {
      status: 'ok',
      url: page.url(),
      title: await page.title().catch(() => ''),
      redirected: page.url() !== url ? page.url() : null
    };
  } catch (e) {
    return {
      status: 'error',
      url,
      error: e.message?.substring(0, 500),
      redirected: page.url() !== url ? page.url() : null
    };
  }
}

async function runSnapshot(page, params) {
  const sel = params.selector || null;
  try {
    if (sel) {
      const count = await page.locator(sel).count();
      const elements = [];
      for (let i = 0; i < Math.min(count, 50); i++) {
        const el = page.locator(sel).nth(i);
        elements.push({
          tag: await el.evaluate(e => e.tagName?.toLowerCase()).catch(() => ''),
          text: (await el.textContent().catch(() => '') || '').substring(0, 200),
          visible: await el.isVisible().catch(() => false),
          href: await el.getAttribute('href').catch(() => null),
          id: await el.getAttribute('id').catch(() => null),
          class: await el.getAttribute('class').catch(() => null),
          type: await el.getAttribute('type').catch(() => null),
          name: await el.getAttribute('name').catch(() => null),
          role: await el.getAttribute('role').catch(() => null),
          ariaLabel: await el.getAttribute('aria-label').catch(() => null),
          ariaInvalid: await el.getAttribute('aria-invalid').catch(() => null),
          tabindex: await el.getAttribute('tabindex').catch(() => null),
          disabled: await el.evaluate(e => e.disabled).catch(() => false)
        });
      }
      return { selector: sel, count, elements };
    } else {
      // Full page snapshot — accessibility tree only works with active accessibility client,
      // so also collect structural DOM info via evaluate
      let snapshot = null;
      try {
        snapshot = await page.accessibility.snapshot({ interestingOnly: false });
      } catch {}
      const domInfo = await page.evaluate(() => ({
        contentLength: document.body?.innerHTML?.length || 0,
        nodeCount: document.querySelectorAll('*').length,
        links: Array.from(document.querySelectorAll('a[href]')).slice(0, 100).map(a => ({
          href: a.href?.substring(0, 200),
          text: (a.textContent || '').trim().substring(0, 100)
        })),
        buttons: Array.from(document.querySelectorAll('button, [role="button"], input[type="submit"], input[type="button"]')).slice(0, 50).map(b => ({
          text: (b.textContent || b.value || '').trim().substring(0, 100),
          id: b.id || '',
          name: b.name || ''
        })),
        forms: Array.from(document.querySelectorAll('form')).slice(0, 20).map(f => ({
          action: f.action?.substring(0, 200),
          method: f.method || 'get',
          inputs: f.querySelectorAll('input, select, textarea').length
        }))
      })).catch(() => ({}));
      return { snapshot, ...domInfo, url: page.url() };
    }
  } catch (e) {
    return { error: e.message?.substring(0, 300) };
  }
}

async function runScreenshot(page, params, state) {
  const p = params.path || fail('--path is required for screenshot');
  const fullPage = params.full-page === 'true';
  await page.screenshot({ path: p, fullPage, type: 'png' });
  return { path: p, fullPage };
}

async function runEvaluate(page, params) {
  const expr = params.expr || fail('--expr is required for evaluate');
  try {
    // Wrap expression: if it starts with "return", use block body; else use expression body
    const wrapped = expr.trim().startsWith('return ') || expr.includes(';')
      ? `(() => { ${expr} })()`
      : `(() => (${expr}))()`;
    const result = await page.evaluate(wrapped);
    return { result };
  } catch (e) {
    return { error: e.message?.substring(0, 500) };
  }
}

async function runClick(page, params) {
  const selector = params.selector || fail('--selector is required for click');
  try {
    const el = page.locator(selector).first();
    await el.click({ timeout: params.timeout ? parseInt(params.timeout) : 5000 });
    await page.waitForTimeout(500);
    return {
      clicked: true,
      selector,
      url: page.url(),
      title: await page.title().catch(() => '')
    };
  } catch (e) {
    return { clicked: false, selector, error: e.message?.substring(0, 300) };
  }
}

async function runType(page, params) {
  const selector = params.selector || fail('--selector is required for type');
  const text = params.text || '';
  try {
    await page.locator(selector).first().fill(text);
    return { filled: true, selector, text };
  } catch (e) {
    return { filled: false, selector, error: e.message?.substring(0, 300) };
  }
}

async function runConsole(page, params) {
  // Collect console errors from the injected monitor
  try {
    const errors = await page.evaluate(() => {
      const monitor = window.__MCV3_BROWSER_MONITOR__;
      const collected = monitor ? [...monitor.consoleErrors] : [];
      if (monitor) monitor.consoleErrors = [];
      return collected;
    });
    return { errors: errors.slice(-50) }; // max 50
  } catch (e) {
    return { errors: [] };
  }
}

async function runNetwork(page, params) {
  try {
    const failures = await page.evaluate(() => {
      const monitor = window.__MCV3_BROWSER_MONITOR__;
      const collected = monitor ? [...monitor.networkFailures] : [];
      if (monitor) monitor.networkFailures = [];
      return collected;
    });
    return { failures: failures.slice(-100) };
  } catch (e) {
    return { failures: [] };
  }
}

async function runWait(page, params) {
  if (params.time) {
    const ms = parseInt(params.time);
    await page.waitForTimeout(ms);
    return { waited: `${ms}ms` };
  }
  if (params.selector) {
    try {
      await page.waitForSelector(params.selector, {
        timeout: params.timeout ? parseInt(params.timeout) : 5000
      });
      return { waited: `selector:${params.selector}`, found: true };
    } catch {
      return { waited: `selector:${params.selector}`, found: false };
    }
  }
  return { waited: '0ms' };
}

async function runTabs(page, params, context, state) {
  const tabs = [];
  try {
    const allPages = context.pages();
    for (const p of allPages) {
      tabs.push({
        url: p.url(),
        title: await p.title().catch(() => '')
      });
    }
  } catch {}
  return { tabs };
}

async function runBack(page) {
  try {
    await page.goBack({ timeout: 10000 });
    return { url: page.url(), title: await page.title().catch(() => '') };
  } catch {
    return { error: 'goBack failed', url: page.url() };
  }
}

async function runDialog(page, params) {
  const accept = params.accept !== 'false';
  const promptText = params.prompt-text || '';
  try {
    page.once('dialog', async dialog => {
      if (promptText) await dialog.accept(promptText).catch(() => {});
      else if (accept) await dialog.accept().catch(() => {});
      else await dialog.dismiss().catch(() => {});
    });
    return { handled: true, accept, promptText };
  } catch {
    return { handled: false };
  }
}

async function runSelect(page, params) {
  const selector = params.selector || fail('--selector is required for select');
  const values = (params.values || '').split(',').filter(Boolean);
  try {
    await page.locator(selector).first().selectOption(values);
    return { selected: true, selector, values };
  } catch (e) {
    return { selected: false, selector, error: e.message?.substring(0, 300) };
  }
}

async function runFillForm(page, params) {
  const fieldsJson = params.fields || '[]';
  const fields = JSON.parse(fieldsJson);
  const results = [];
  for (const field of fields) {
    try {
      await page.locator(field.selector).first().fill(field.value || '');
      results.push({ selector: field.selector, filled: true });
    } catch (e) {
      results.push({ selector: field.selector, filled: false, error: e.message?.substring(0, 200) });
    }
  }
  return { filled: results };
}

async function runHover(page, params) {
  const selector = params.selector || fail('--selector is required for hover');
  try {
    await page.locator(selector).first().hover();
    return { hovered: true, selector };
  } catch (e) {
    return { hovered: false, selector, error: e.message?.substring(0, 300) };
  }
}

async function runPressKey(page, params) {
  const key = params.key || fail('--key is required for press_key');
  try {
    await page.keyboard.press(key);
    return { pressed: key };
  } catch (e) {
    return { pressed: key, error: e.message?.substring(0, 200) };
  }
}

async function runUploadFile(page, params) {
  const selector = params.selector || fail('--selector is required for upload_file');
  const filePaths = (params.paths || '').split(',').filter(Boolean);
  try {
    const locator = page.locator(selector).first();
    await locator.setInputFiles(filePaths);
    return { uploaded: true, selector, files: filePaths };
  } catch (e) {
    return { uploaded: false, selector, error: e.message?.substring(0, 300) };
  }
}

async function runResize(page, params) {
  const width = parseInt(params.width) || 1280;
  const height = parseInt(params.height) || 720;
  await page.setViewportSize({ width, height });
  return { resized: true, viewport: { width, height } };
}

async function runClosePage(page, params) {
  await page.close().catch(() => {});
  return { closed: true };
}

// ── Main ────────────────────────────────────────────────────────────────

(async () => {
  const args = parseArgs();
  const action = args._[0] || args.action || fail('--action is required');
  const sessionDir = args['session-dir'] || fail('--session-dir is required');

  // Ensure session directory exists
  if (!fs.existsSync(sessionDir)) {
    fs.mkdirSync(sessionDir, { recursive: true });
  }

  const port = getSessionPort(sessionDir);
  const userDataDir = path.join(sessionDir, 'playwright-data');
  const sessionFile = path.join(sessionDir, 'playwright-session.json');

  if (action === 'launch') {
    // v10.2 — Parse new cờ: --show-browser (visible), --mobile (device emulation), --device (tên device)
    const launchOpts = {
      showBrowser: args['show-browser'] === 'true' || args['show-browser'] === true,
      mobileMode: args['mobile'] === 'true' || args['mobile'] === true,
      deviceName: args['device'] || process.env.MCV3_MOBILE_DEVICE || 'iPhone 14'
    };
    await actionLaunch(port, userDataDir, sessionFile, launchOpts);
    return;
  }

  if (action === 'close') {
    await actionClose(sessionFile);
    return;
  }

  if (action === 'status') {
    await actionStatus(sessionFile);
    return;
  }

  if (action === 'navigate_parallel') {
    // W2.1: Multi-context parallel navigation (max MCV3_PW_MAX_CONTEXTS=4 default)
    await actionNavigateParallel(sessionFile, args);
    return;
  }

  if (action === 'close_context') {
    // W2.1: Idempotent cleanup cho contexts da tao boi navigate_parallel
    await actionCloseContext(sessionFile, args);
    return;
  }

  // All other actions require an active browser connection
  await connectAndAct(sessionFile, async (page, params, context, state) => {
    // Collect console errors in the background
    if (!page.__listenersSetup) {
      page.__listenersSetup = true;
      page.on('console', msg => {
        if (msg.type() === 'error') {
          page.evaluate((errText) => {
            if (window.__MCV3_BROWSER_MONITOR__) {
              window.__MCV3_BROWSER_MONITOR__.consoleErrors.push({
                text: errText.substring(0, 500),
                url: window.location.href,
                timestamp: new Date().toISOString()
              });
            }
          }, msg.text()).catch(() => {});
        }
      });
      page.on('response', resp => {
        if (resp.status() >= 400) {
          page.evaluate((info) => {
            if (window.__MCV3_BROWSER_MONITOR__) {
              window.__MCV3_BROWSER_MONITOR__.networkFailures.push(info);
            }
          }, {
            url: resp.url(),
            status: resp.status(),
            method: resp.request().method(),
            timestamp: new Date().toISOString()
          }).catch(() => {});
        }
      });
    }

    switch (action) {
      case 'navigate':       return await runNavigate(page, params);
      case 'snapshot':       return await runSnapshot(page, params);
      case 'screenshot':     return await runScreenshot(page, params, state);
      case 'evaluate':       return await runEvaluate(page, params);
      case 'click':          return await runClick(page, params);
      case 'type':           return await runType(page, params);
      case 'console':        return await runConsole(page, params);
      case 'network':        return await runNetwork(page, params);
      case 'wait':           return await runWait(page, params);
      case 'tabs':           return await runTabs(page, params, context, state);
      case 'back':           return await runBack(page);
      case 'dialog':         return await runDialog(page, params);
      case 'select':         return await runSelect(page, params);
      case 'fill_form':      return await runFillForm(page, params);
      case 'hover':          return await runHover(page, params);
      case 'press_key':      return await runPressKey(page, params);
      case 'upload_file':    return await runUploadFile(page, params);
      case 'resize':         return await runResize(page, params);
      case 'close_page':     return await runClosePage(page, params);
      default:
        fail(`Unknown action: ${action}. Supported: launch, close, status, navigate, snapshot, screenshot, evaluate, click, type, console, network, wait, tabs, back, dialog, select, fill_form, hover, press_key, upload_file, resize, close_page, navigate_parallel, close_context`);
    }
  }, args);
})().catch(e => {
  console.error(JSON.stringify({ error: e.message, stack: e.stack?.substring(0, 500) }));
  process.exit(1);
});
