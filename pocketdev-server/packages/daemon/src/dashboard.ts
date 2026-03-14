import http from 'http';
import QRCode from 'qrcode';
import os from 'os';
import type { PairingPayload } from './types.js';
import type { PairingManager } from './pairing.js';
import { getLocalIP } from './utils.js';

export class Dashboard {
  private httpServer: http.Server | null = null;
  private wsPort = 0;
  private pairing: PairingManager | null = null;

  start(port: number, wsPort: number, pairing: PairingManager): Promise<number> {
    this.wsPort = wsPort;
    this.pairing = pairing;

    return new Promise((resolve) => {
      this.httpServer = http.createServer(async (req, res) => {
        const ip = getLocalIP();

        if (req.url === '/api/info') {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ host: ip, port: this.wsPort, secret: this.pairing!.secret, daemonId: this.pairing!.daemonId }));
          return;
        }

        if (req.url === '/api/regenerate' && req.method === 'POST') {
          this.pairing!.regenerate();
          const svg = await this.generateQRSvg(ip);
          console.log(`  [dashboard] New pairing secret generated`);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ ok: true, secret: this.pairing!.secret, svg }));
          return;
        }

        if (req.url?.startsWith('/qr.svg')) {
          const svg = await this.generateQRSvg(ip);
          res.writeHead(200, { 'Content-Type': 'image/svg+xml', 'Cache-Control': 'no-store' });
          res.end(svg);
          return;
        }

        const qrSvg = await this.generateQRSvg(ip);
        const html = this.renderPage(ip, qrSvg);
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(html);
      });

      this.httpServer.listen(port, () => {
        const addr = this.httpServer!.address();
        const p = (addr && typeof addr === 'object') ? addr.port : port;
        resolve(p);
      });
    });
  }

  stop() {
    this.httpServer?.close();
  }

  private async generateQRSvg(ip: string): Promise<string> {
    const payload: PairingPayload = { daemonId: this.pairing!.daemonId, host: ip, port: this.wsPort, secret: this.pairing!.secret };
    const encoded = Buffer.from(JSON.stringify(payload)).toString('base64');
    const uri = `pocketdev://${encoded}`;
    return QRCode.toString(uri, { type: 'svg', margin: 1, width: 260 });
  }

  private renderPage(ip: string, qrSvg: string): string {
    const secret = this.pairing!.secret;
    const wsPort = this.wsPort;

    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PocketDev — Connect</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: #0D1117;
    color: #E6EDF3;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .container { text-align: center; max-width: 480px; padding: 32px; }
  h1 { font-size: 42px; font-weight: 800; margin-bottom: 4px; }
  .tagline { color: #8B949E; font-size: 16px; margin-bottom: 40px; }
  .qr-box {
    background: #fff;
    border-radius: 20px;
    padding: 24px;
    display: inline-block;
    margin-bottom: 20px;
    box-shadow: 0 0 60px rgba(88, 166, 255, 0.15);
  }
  .qr-box svg { display: block; width: 260px; height: 260px; }
  .scan-label { color: #58A6FF; font-size: 14px; font-weight: 600; margin-bottom: 16px; }
  .regen-btn {
    background: #238636; color: #fff; border: none;
    padding: 10px 24px; border-radius: 8px;
    font-size: 14px; font-weight: 600; cursor: pointer;
    margin-bottom: 32px; transition: background 0.15s;
  }
  .regen-btn:hover { background: #2ea043; }
  .regen-btn:active { background: #1a7f37; }
  .details {
    background: #161B22; border: 1px solid #30363D;
    border-radius: 16px; padding: 24px; text-align: left;
  }
  .details h3 {
    color: #8B949E; font-size: 11px; font-weight: 700;
    letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 16px;
  }
  .field {
    display: flex; justify-content: space-between; align-items: center;
    padding: 10px 0; border-bottom: 1px solid #21262D;
  }
  .field:last-child { border-bottom: none; }
  .field-label { color: #8B949E; font-size: 13px; }
  .field-value {
    color: #E6EDF3; font-size: 14px; font-weight: 600;
    font-family: 'SF Mono', 'Fira Code', monospace;
    cursor: pointer; padding: 4px 10px; border-radius: 6px;
    transition: background 0.15s;
  }
  .field-value:hover { background: #21262D; }
  .secret-val { font-size: 11px; word-break: break-all; max-width: 260px; text-align: right; line-height: 1.5; }
  .status { margin-top: 24px; display: flex; align-items: center; justify-content: center; gap: 8px; }
  .dot { width: 8px; height: 8px; border-radius: 50%; background: #3FB950; animation: pulse 2s ease-in-out infinite; }
  @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.4; } }
  .status-text { color: #8B949E; font-size: 13px; }
  .toast {
    position: fixed; top: 20px; left: 50%; transform: translateX(-50%);
    background: #3FB950; color: #fff; padding: 8px 20px;
    border-radius: 8px; font-size: 13px; font-weight: 600;
    opacity: 0; transition: opacity 0.2s; pointer-events: none;
  }
  .toast.show { opacity: 1; }
</style>
</head>
<body>
<div class="container">
  <h1>PocketDev</h1>
  <p class="tagline">Your AI, from your phone</p>

  <div class="qr-box" id="qrBox">${qrSvg}</div>

  <p class="scan-label">Scan with PocketDev app to connect</p>

  <button class="regen-btn" id="regenBtn" onclick="regenerate()">Generate New QR Code</button>

  <div class="details">
    <h3>Manual Connection</h3>
    <div class="field">
      <span class="field-label">Host</span>
      <span class="field-value" onclick="copy('${ip}')">${ip}</span>
    </div>
    <div class="field">
      <span class="field-label">Port</span>
      <span class="field-value" onclick="copy('${wsPort}')">${wsPort}</span>
    </div>
    <div class="field">
      <span class="field-label">Secret</span>
      <span class="field-value secret-val" id="secretVal" onclick="copy(this.textContent)">${secret}</span>
    </div>
  </div>

  <div class="status">
    <div class="dot"></div>
    <span class="status-text">Daemon running on ${os.hostname()}</span>
  </div>
</div>

<div class="toast" id="toast">Copied!</div>

<script>
function copy(text) {
  navigator.clipboard.writeText(String(text));
  var t = document.getElementById('toast');
  t.classList.add('show');
  setTimeout(function() { t.classList.remove('show'); }, 1200);
}

function regenerate() {
  var btn = document.getElementById('regenBtn');
  btn.textContent = 'Generating...';
  btn.style.opacity = '0.6';
  fetch('/api/regenerate', { method: 'POST' })
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (data.ok) {
        document.getElementById('qrBox').innerHTML = data.svg;
        document.getElementById('secretVal').textContent = data.secret;
        btn.textContent = 'Done!';
        setTimeout(function() { btn.textContent = 'Generate New QR Code'; }, 1500);
      }
      btn.style.opacity = '1';
    })
    .catch(function() {
      btn.textContent = 'Error - try again';
      btn.style.opacity = '1';
      setTimeout(function() { btn.textContent = 'Generate New QR Code'; }, 2000);
    });
}
</script>
</body>
</html>`;
  }
}
