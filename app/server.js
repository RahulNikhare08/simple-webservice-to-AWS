const http = require('http');
const port = process.env.PORT || 3000;

// DB_URL comes directly from Secrets Manager as the value of the DB_URL key
const dbUrl = process.env.DB_URL || 'not-set';

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    message: 'Hello World from ECS Fargate! 🎉',
    db_url_env_present: !!process.env.DB_URL,
    db_url: dbUrl.includes('password') ? '[REDACTED]' : dbUrl,
    time: new Date().toISOString(),
    version: '1.0.0'
  }));
});

server.listen(port, () => {
  console.log(`Server running on port ${port}`);
  console.log(`DB URL configured: ${!!process.env.DB_URL}`);
});
