const { spawn } = require('child_process');

const args = process.argv.slice(2);
if (args.length === 0) {
  process.exit(1);
}

const child = spawn(args[0], args.slice(1), {
  stdio: ['pipe', 'pipe', 'inherit']
});

process.stdin.pipe(child.stdin);
child.stdout.pipe(process.stdout);

process.stdout.on('error', (err) => {
  if (err.code === 'EPIPE') {
    cleanup();
  }
});

child.on('exit', (code) => {
  process.exit(code !== null ? code : 1);
});

child.on('error', (err) => {
  console.error('Child error:', err);
  process.exit(1);
});

let cleanedUp = false;
const cleanup = () => {
  if (cleanedUp) return;
  cleanedUp = true;
  child.kill('SIGTERM');
  setTimeout(() => {
    try { child.kill('SIGKILL'); } catch (e) {}
    process.exit(0);
  }, 1000);
};

process.stdin.on('end', cleanup);
process.stdin.on('close', cleanup);
process.stdin.on('error', cleanup);

['SIGINT', 'SIGTERM', 'SIGQUIT'].forEach(sig => {
  process.on(sig, () => {
    cleanup();
  });
});
