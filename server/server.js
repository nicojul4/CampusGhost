const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const PORT = process.env.PORT || 3000;
const DB_FILE = path.join(__dirname, 'reports_db.json');

// Helper to read DB
function readDatabase() {
  try {
    if (!fs.existsSync(DB_FILE)) {
      const initialData = [
        {
          id: 'report-seed-1',
          userId: 'user_nicolas',
          locationId: 'gedung-1-lantai-3',
          category: 'Wifi',
          description: 'Koneksi Wi-Fi di lantai 3 Gedung 1 sering terputus.',
          status: 'Active',
          incidentId: null,
          photoUrl: null,
          createdAt: new Date(Date.now() - 3600000).toISOString(),
          updatedAt: new Date(Date.now() - 3600000).toISOString(),
        },
        {
          id: 'report-seed-2',
          userId: 'user_pradita',
          locationId: 'gedung-2-lantai-2',
          category: 'AC',
          description: 'AC di ruang 202 tidak dingin dan mengeluarkan bunyi bising.',
          status: 'Active',
          incidentId: null,
          photoUrl: null,
          createdAt: new Date(Date.now() - 1800000).toISOString(),
          updatedAt: new Date(Date.now() - 1800000).toISOString(),
        }
      ];
      fs.writeFileSync(DB_FILE, JSON.stringify(initialData, null, 2), 'utf8');
      return initialData;
    }
    const raw = fs.readFileSync(DB_FILE, 'utf8');
    return JSON.parse(raw);
  } catch (err) {
    console.error('Error reading database file:', err);
    return [];
  }
}

// Helper to write DB
function writeDatabase(data) {
  try {
    fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2), 'utf8');
    return true;
  } catch (err) {
    console.error('Error writing database file:', err);
    return false;
  }
}

// Ensure DB exists on start
readDatabase();

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const method = req.method;

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');

  if (method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Health check
  if (pathname === '/api/health' && method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', uptime: process.uptime() }));
    return;
  }

  // GET /api/reports
  if (pathname === '/api/reports' && method === 'GET') {
    // Optional error simulation for testing
    if (parsedUrl.query.simulate_error) {
      const code = parseInt(parsedUrl.query.simulate_error, 10) || 500;
      res.writeHead(code, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: `Simulated server error ${code}` }));
      return;
    }
    if (parsedUrl.query.simulate_empty === 'true') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify([]));
      return;
    }

    const reports = readDatabase();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(reports));
    return;
  }

  // POST /api/reports
  if (pathname === '/api/reports' && method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body || '{}');

        // Validation
        if (!payload.category || typeof payload.category !== 'string') {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Kategori wajib diisi.' }));
          return;
        }
        if (!payload.locationId || typeof payload.locationId !== 'string') {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Lokasi wajib diisi.' }));
          return;
        }
        if (!payload.description || typeof payload.description !== 'string') {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Deskripsi wajib diisi.' }));
          return;
        }

        const reports = readDatabase();
        const newReport = {
          id: payload.id || `rep_${Date.now()}_${Math.random().toString(36).substr(2, 5)}`,
          userId: payload.userId || 'user_guest',
          locationId: payload.locationId.trim(),
          category: payload.category.trim(),
          description: payload.description.trim(),
          photoUrl: payload.photoUrl || null,
          status: payload.status || 'Active',
          incidentId: payload.incidentId || null,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        };

        reports.unshift(newReport); // Prepend new report
        writeDatabase(reports);

        res.writeHead(201, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(newReport));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Body bukan JSON yang valid.' }));
      }
    });
    return;
  }

  // Reset or clear endpoint for testing empty state
  if (pathname === '/api/reports/reset' && method === 'POST') {
    fs.writeFileSync(DB_FILE, JSON.stringify([], null, 2), 'utf8');
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ message: 'Database reset to empty.' }));
    return;
  }

  // Not found
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Endpoint tidak ditemukan.' }));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[CampusGhost API Server] Running on http://localhost:${PORT}`);
  console.log(`- GET  /api/reports`);
  console.log(`- POST /api/reports`);
  console.log(`- GET  /api/health`);
});
