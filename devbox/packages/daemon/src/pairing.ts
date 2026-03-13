import crypto from 'crypto';
import qrcode from 'qrcode-terminal';
import { nanoid } from 'nanoid';
import os from 'os';
import type { PairingPayload } from './types.js';

export class PairingManager {
  public daemonId: string;
  public secret: string;
  private pairedDevices = new Set<string>();

  constructor() {
    this.daemonId = nanoid(16);
    this.secret = crypto.randomBytes(32).toString('hex');
  }

  regenerate(): void {
    this.secret = crypto.randomBytes(32).toString('hex');
    this.pairedDevices.clear();
  }

  displayQR(port: number): void {
    const host = this.getLocalIP();
    const payload: PairingPayload = {
      daemonId: this.daemonId,
      host,
      port,
      secret: this.secret,
    };

    const encoded = Buffer.from(JSON.stringify(payload)).toString('base64');
    const uri = `devbox://${encoded}`;

    console.log('\n  Scan this QR code with the DevBox app to pair:\n');
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

  private getLocalIP(): string {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
      const nets = interfaces[name];
      if (!nets) continue;
      for (const net of nets) {
        if (net.family === 'IPv4' && !net.internal) {
          return net.address;
        }
      }
    }
    return '127.0.0.1';
  }
}
