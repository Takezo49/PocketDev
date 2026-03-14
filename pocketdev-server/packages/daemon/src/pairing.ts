import crypto from 'crypto';
import qrcode from 'qrcode-terminal';
import { nanoid } from 'nanoid';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';
import type { PairingPayload } from './types.js';
import { getLocalIP } from './utils.js';

const PAIRING_FILE = join(homedir(), '.devbox', 'pairing.json');

export class PairingManager {
  public daemonId: string;
  public secret: string;
  private pairedDevices = new Set<string>();

  constructor() {
    // Load persisted pairing info so restarts don't break connections
    const saved = this.loadPairing();
    this.daemonId = saved?.daemonId ?? nanoid(16);
    this.secret = saved?.secret ?? crypto.randomBytes(32).toString('hex');
    this.savePairing();
  }

  private loadPairing(): { daemonId: string; secret: string } | null {
    try {
      if (existsSync(PAIRING_FILE)) {
        return JSON.parse(readFileSync(PAIRING_FILE, 'utf-8'));
      }
    } catch {}
    return null;
  }

  private savePairing(): void {
    try {
      const dir = join(homedir(), '.devbox');
      if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
      writeFileSync(PAIRING_FILE, JSON.stringify({ daemonId: this.daemonId, secret: this.secret }));
    } catch {}
  }

  regenerate(): void {
    this.secret = crypto.randomBytes(32).toString('hex');
    this.pairedDevices.clear();
  }

  displayQR(port: number): void {
    const host = getLocalIP();
    const payload: PairingPayload = {
      daemonId: this.daemonId,
      host,
      port,
      secret: this.secret,
    };

    const encoded = Buffer.from(JSON.stringify(payload)).toString('base64');
    const uri = `pocketdev://${encoded}`;

    console.log('\n  Scan this QR code with the PocketDev app to pair:\n');
    qrcode.generate(uri, { small: true });
    console.log(`\n  Or connect manually: ws://${host}:${port}`);
    console.log(`  Pairing secret: ${this.secret}`);
    console.log();
  }

  verify(token: string): boolean {
    return token === this.secret;
  }

  addDevice(deviceId: string): void {
    this.pairedDevices.add(deviceId);
  }

  isDevicePaired(deviceId: string): boolean {
    return this.pairedDevices.has(deviceId);
  }

}
