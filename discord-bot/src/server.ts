import { createServer } from 'http';

const port = Number(process.env.PORT) || 3000;

export const server = createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('OK');
    return;
  }

  res.writeHead(404);
  res.end();
});

server.listen(port, () => {
  console.log(`🌐 Health check server listening on port ${port}`);
}).on('error', (err) => {
  console.error('❌ Failed to start health check server:', err);
  process.exit(1);
});