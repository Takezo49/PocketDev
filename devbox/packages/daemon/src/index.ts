import { DevBoxServer } from './server.js';

const PORT = parseInt(process.env.DEVBOX_PORT ?? '7777', 10);

console.log('');
console.log('  ╔═══════════════════════════════╗');
console.log('  ║        DevBox Daemon           ║');
console.log('  ║   Control your AI from phone   ║');
console.log('  ╚═══════════════════════════════╝');

const server = new DevBoxServer();

server.start(PORT).then((port) => {
  console.log(`  Ready. Ctrl+C to stop.\n`);
}).catch((err) => {
  console.error('Failed to start DevBox daemon:', err);
  process.exit(1);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n  Shutting down DevBox daemon...');
  server.stop();
  process.exit(0);
});

process.on('SIGTERM', () => {
  server.stop();
  process.exit(0);
});
