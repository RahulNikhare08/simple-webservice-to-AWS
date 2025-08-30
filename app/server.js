const http = require('http');
const port = process.env.PORT || 3000;
const db = process.env.DB_URL || 'not-set';


const server = http.createServer((req, res) => {
res.writeHead(200, { 'Content-Type': 'application/json' });
res.end(JSON.stringify({
message: 'Hello World from ECS Fargate! 🎉',
db_url_env_present: !!process.env.DB_URL,
time: new Date().toISOString()
}));
});


server.listen(port, () => {
console.log(`Server running on port ${port}`);
});