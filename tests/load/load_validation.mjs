import WebSocket from '../backend/node_modules/ws/index.js';
import jwt from '../backend/node_modules/jsonwebtoken/index.js';

const baseUrl = (process.env.BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
const wsUrl = baseUrl.replace(/^http/, 'ws');
const users = Number(process.env.USERS || 300);
const timeoutMs = Number(process.env.TIMEOUT_MS || 15000);
const login = process.env.LOAD_LOGIN || 'colaborador@seatmap.local';
const password = process.env.LOAD_PASSWORD || 'Mudar@123456Sec';
const reservationDate = process.env.RESERVATION_DATE || nextDate();
const runReservation = process.env.RUN_RESERVATION === 'true';
const onlyReservations = process.env.ONLY_RESERVATIONS === 'true';

function nextDate() {
  const date = new Date(Date.now() + 24 * 60 * 60 * 1000);
  return date.toISOString().slice(0, 10);
}

function makeDevToken(userId) {
  return jwt.sign({
    userId,
    nome: `Carga ${userId}`,
    email: `carga${String(userId).padStart(3, '0')}@loadtest.local`,
    matricula: `CARGA_${String(userId).padStart(3, '0')}`,
    perfil: 'COLABORADOR',
    departamentoId: null,
    tokenVersion: 1
  }, process.env.DEV_JWT_SECRET || 'dev_local_secret_key_for_jwt_secret_32chars_len', { expiresIn: '10m' });
}

function tokenForIndex(fallbackToken, index) {
  const start = Number(process.env.LOAD_USER_ID_START || 0);
  return process.env.DEV_LOAD_TOKEN === 'true' && start > 0
    ? makeDevToken(start + index)
    : fallbackToken;
}

function findValue(value, keys) {
  if (!value || typeof value !== 'object') return undefined;
  if (Array.isArray(value)) {
    for (const item of value) {
      const found = findValue(item, keys);
      if (found !== undefined) return found;
    }
    return undefined;
  }
  for (const key of keys) {
    if (typeof value[key] === 'string' && value[key].split('.').length === 3) return value[key];
    if (typeof value[key] === 'number' && keys.includes('id')) return value[key];
  }
  for (const child of Object.values(value)) {
    const found = findValue(child, keys);
    if (found !== undefined) return found;
  }
  return undefined;
}

function findFirstId(value) {
  if (!value || typeof value !== 'object') return undefined;
  if (Array.isArray(value)) {
    for (const item of value) {
      const found = findFirstId(item);
      if (found !== undefined) return found;
    }
    return undefined;
  }
  if (typeof value.id === 'number') return value.id;
  for (const child of Object.values(value)) {
    const found = findFirstId(child);
    if (found !== undefined) return found;
  }
  return undefined;
}

async function request(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, options);
  let body;
  try { body = await response.json(); } catch { body = undefined; }
  return { status: response.status, body };
}

async function loginUser() {
  if (process.env.DEV_LOAD_TOKEN === 'true') {
    return makeDevToken(Number(process.env.LOAD_USER_ID || process.env.LOAD_USER_ID_START || 1));
  }
  const result = await request('/api/auth/login', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ login, senha: password })
  });
  const token = findValue(result.body, ['accessToken', 'token']);
  if (!token) throw new Error(`Login falhou: HTTP ${result.status}`);
  return token;
}

async function getOfficeAndSeat(token) {
  const offices = await request('/api/escritorios', { headers: { authorization: `Bearer ${token}` } });
  const officeId = Number(process.env.OFFICE_ID || findFirstId(offices.body) || 1);
  const map = await request(`/api/escritorios/${officeId}/mapa?data=${reservationDate}`, {
    headers: { authorization: `Bearer ${token}` }
  });
  const seatId = Number(process.env.SEAT_ID || findFirstId(map.body) || 1);
  return { officeId, seatId, officesStatus: offices.status, mapStatus: map.status };
}

async function measureHttp(token, officeId) {
  const started = Date.now();
  const responses = await Promise.all(Array.from({ length: users }, (_, index) =>
    request(`/api/escritorios/${officeId}/mapa?data=${reservationDate}`, {
      headers: {
        authorization: `Bearer ${tokenForIndex(token, index)}`,
        'x-correlation-id': `load-http-${index}`
      }
    }).catch(() => ({ status: 0 }))
  ));
  return summarize('http_map_300', responses, Date.now() - started);
}

function summarize(name, responses, durationMs) {
  const counts = {};
  for (const response of responses) counts[response.status] = (counts[response.status] || 0) + 1;
  return { name, total: responses.length, durationMs, statuses: counts };
}

async function measureWebSockets(token, officeId) {
  const started = Date.now();
  const connections = await Promise.all(Array.from({ length: users }, (_, index) => new Promise((resolve) => {
    const socket = new WebSocket(`${wsUrl}/ws?escritorioId=${officeId}`, ['Bearer', token]);
    const timer = setTimeout(() => { socket.terminate(); resolve({ status: 'timeout' }); }, timeoutMs);
    socket.once('open', () => {
      clearTimeout(timer);
      resolve({ status: 'open', socket });
    });
    socket.once('error', () => {
      clearTimeout(timer);
      resolve({ status: 'error' });
    });
  })));
  const opened = connections.filter((item) => item.status === 'open');
  for (const item of opened) item.socket.close();
  const statuses = connections.reduce((result, item) => {
    result[item.status] = (result[item.status] || 0) + 1;
    return result;
  }, {});
  return { name: 'websocket_300', total: users, durationMs: Date.now() - started, statuses };
}

async function measurePoolAndMixed(token, officeId) {
  const snapshots = [];
  const polling = setInterval(async () => {
    const ready = await request('/api/health/ready').catch(() => ({ body: {} }));
    if (ready.body?.database?.pool) snapshots.push(ready.body.database.pool);
  }, 50);
  const started = Date.now();
  await Promise.all(Array.from({ length: users }, (_, index) => Promise.all([
    request(`/api/escritorios/${officeId}/mapa?data=${reservationDate}`, {
      headers: { authorization: `Bearer ${token}`, 'x-correlation-id': `load-mixed-${index}` }
    }),
    request('/api/health/live')
  ])));
  clearInterval(polling);
  const maxWaiting = snapshots.reduce((max, item) => Math.max(max, item.waitingCount || 0), 0);
  return { name: 'pool_and_mixed_queries', total: users * 2, durationMs: Date.now() - started, samples: snapshots.length, maxWaitingCount: maxWaiting };
}

async function measureReservations(token, seatId) {
  const started = Date.now();
  const responses = await Promise.all(Array.from({ length: users }, (_, index) =>
    request('/api/reservas', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${tokenForIndex(token, index)}`,
        'content-type': 'application/json',
        'x-idempotency-key': `load-reservation-${index}`
      },
      body: JSON.stringify({ cadeiraId: seatId, dataReserva: reservationDate })
    }).catch(() => ({ status: 0 }))
  ));
  const successful = responses.filter((response) => response.status >= 200 && response.status < 300);
  const reservationId = findFirstId(successful[0]?.body);
  let cleanupStatus = 'not_needed';
  if (reservationId) {
    const cleanup = await request(`/api/reservas/${reservationId}`, {
      method: 'DELETE',
      headers: { authorization: `Bearer ${token}` }
    });
    cleanupStatus = String(cleanup.status);
  }
  return { ...summarize('reservations_300', responses, Date.now() - started), successful: successful.length, cleanupStatus };
}

const token = await loginUser();
const { officeId, seatId, officesStatus, mapStatus } = await getOfficeAndSeat(token);
const results = {
  configuration: { baseUrl, users, reservationDate, officeId, seatId, officesStatus, mapStatus, runReservation, onlyReservations }
};
if (!onlyReservations) {
  results.http = await measureHttp(token, officeId);
  results.websocket = await measureWebSockets(token, officeId);
  results.poolAndMixed = await measurePoolAndMixed(token, officeId);
}
if (runReservation) results.reservations = await measureReservations(token, seatId);
console.log(JSON.stringify(results, null, 2));