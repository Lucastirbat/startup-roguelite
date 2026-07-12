// Static file server + global leaderboard API. No dependencies.
// Leaderboard lives in a JSON file on the Fly volume (/data) so it
// survives restarts and redeploys.
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const PORT = process.env.PORT || 8080;
const ROOT = path.join(__dirname, 'public');
const DATA_DIR = process.env.DATA_DIR || '/data';
const LB_PATH = path.join(DATA_DIR, 'leaderboard.json');
const MAX_ENTRIES = 100;   // kept on disk
const TOP_RETURNED = 25;   // served to the game
const MAX_SCORE = 20000000; // $20B in $K — above the biggest possible payout

const MIME = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.json': 'application/json',
};
const GZIP_EXT = new Set(['.html', '.js', '.wasm', '.pck', '.json', '.svg']);

function loadBoard() {
  try {
    const v = JSON.parse(fs.readFileSync(LB_PATH, 'utf8'));
    return Array.isArray(v) ? v : [];
  } catch {
    return [];
  }
}

function saveBoard(board) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  const tmp = LB_PATH + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(board));
  fs.renameSync(tmp, LB_PATH);
}

function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

function sendJson(res, code, obj) {
  cors(res);
  res.writeHead(code, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(obj));
}

function handleApi(req, res) {
  if (req.method === 'OPTIONS') {
    cors(res);
    res.writeHead(204);
    return res.end();
  }
  if (req.method === 'GET') {
    return sendJson(res, 200, loadBoard().slice(0, TOP_RETURNED));
  }
  if (req.method !== 'POST') return sendJson(res, 405, { error: 'method not allowed' });

  let body = '';
  req.on('data', (chunk) => {
    body += chunk;
    if (body.length > 4096) req.destroy(); // no essay-sized payloads
  });
  req.on('end', () => {
    let data;
    try {
      data = JSON.parse(body);
    } catch {
      return sendJson(res, 400, { error: 'bad json' });
    }
    // Printable chars only, trimmed, 1-20 long.
    const name = String(data.name || '').replace(/[^\x20-\x7E]/g, '').trim().slice(0, 20);
    const score = Math.floor(Number(data.score));
    const month = Math.floor(Number(data.month));
    if (!name) return sendJson(res, 400, { error: 'name required' });
    if (!Number.isFinite(score) || score < 1 || score > MAX_SCORE)
      return sendJson(res, 400, { error: 'bad score' });
    if (!Number.isFinite(month) || month < 1 || month > 999)
      return sendJson(res, 400, { error: 'bad month' });

    const board = loadBoard();
    board.push({ name, score, month, date: new Date().toISOString().slice(0, 10) });
    board.sort((a, b) => b.score - a.score || a.month - b.month);
    saveBoard(board.slice(0, MAX_ENTRIES));
    const rank = board.findIndex((e) => e.name === name && e.score === score) + 1;
    sendJson(res, 200, { ok: true, rank });
  });
}

function handleStatic(req, res, urlPath) {
  let rel = decodeURIComponent(urlPath);
  if (rel === '/') rel = '/index.html';
  const file = path.join(ROOT, path.normalize(rel));
  if (!file.startsWith(ROOT)) {
    res.writeHead(403);
    return res.end();
  }
  fs.stat(file, (err, stat) => {
    if (err || !stat.isFile()) {
      res.writeHead(404);
      return res.end('not found');
    }
    const ext = path.extname(file).toLowerCase();
    const headers = {
      'Content-Type': MIME[ext] || 'application/octet-stream',
      // Godot exports don't version filenames, so everything must revalidate.
      'Cache-Control': 'no-cache',
      'Last-Modified': stat.mtime.toUTCString(),
    };
    if (req.headers['if-modified-since'] === stat.mtime.toUTCString()) {
      res.writeHead(304, headers);
      return res.end();
    }
    const gz = GZIP_EXT.has(ext) && /\bgzip\b/.test(req.headers['accept-encoding'] || '');
    if (gz) headers['Content-Encoding'] = 'gzip';
    res.writeHead(200, headers);
    const stream = fs.createReadStream(file);
    if (gz) stream.pipe(zlib.createGzip()).pipe(res);
    else stream.pipe(res);
  });
}

http
  .createServer((req, res) => {
    const urlPath = req.url.split('?')[0];
    if (urlPath === '/api/leaderboard') return handleApi(req, res);
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.writeHead(405);
      return res.end();
    }
    handleStatic(req, res, urlPath);
  })
  .listen(PORT, () => console.log(`serving on :${PORT}, leaderboard at ${LB_PATH}`));
