import WebSocket from '../backend/node_modules/ws/index.js';
import jwt from '../backend/node_modules/jsonwebtoken/index.js';

const baseUrl = (process.env.BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
const wsUrl = baseUrl.replace(/^http/, 'ws');
const userStart = Number(process.env.LOAD_USER_ID_START || 9);
const websocketUsers = Number(process.env.WS_USERS || 300);
const reservationUsers = Number(process.env.RESERVATION_USERS || 40);
const reservationDate = process.env.RESERVATION_DATE || '2026-09-09';
const officeId = Number(process.env.OFFICE_ID || 1);
const timeoutMs = 15000;
const secret = process.env.DEV_JWT_SECRET || 'dev_local_secret_key_for_jwt_secret_32chars_len';

function tokenFor(userId) {
  return jwt.sign({
    userId,
    nome: `Carga ${userId}`,
    email: `carga${String(userId).padStart(3, '0')}@loadtest.local`,
    matricula: `CARGA_${String(userId).padStart(3, '0')}`,
    perfil: 'COLABORADOR',
    departamentoId: null,
    tokenVersion: 1
  }, secret, { expiresIn: '10m' });
}

async function request(path, options = {}) {
  const started = performance.now();
  try {
    const response = await fetch(`${baseUrl}${path}`, options);
    let body;
    try { body = await response.json(); } catch { body = undefined; }
    return { status: response.status, body, durationMs: performance.now() - started };
  } catch (error) {
    return { status: 0, error: String(error), durationMs: performance.now() - started };
  }
}

function percentile(values, percentileValue) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.min(sorted.length - 1, Math.ceil(sorted.length * percentileValue / 100) - 1);
  return Math.round(sorted[Math.max(0, index)] * 100) / 100;
}

function latencySummary(results) {
  const durations = results.map((result) => result.durationMs);
  return {
    total: results.length,
    statuses: results.reduce((counts, result) => {
      counts[result.status] = (counts[result.status] || 0) + 1;
      return counts;
    }, {}),
    p50Ms: percentile(durations, 50),
    p95Ms: percentile(durations, 95),
    p99Ms: percentile(durations, 99),
    maxMs: Math.round(Math.max(...durations) * 100) / 100
  };
}

async function openSockets() {
  const started = performance.now();
  const clients = await Promise.all(Array.from({ length: websocketUsers }, (_, index) => new Promise((resolve) => {
    const userId = userStart + index;
    const socket = new WebSocket(`${wsUrl}/ws?escritorioId=${officeId}`, ['Bearer', tokenFor(userId)]);
    const messages = [];
    const timer = setTimeout(() => {
      socket.terminate();
      resolve({ status: 'timeout', messages });
    }, timeoutMs);
    socket.on('message', (raw) => {
      try { messages.push(JSON.parse(raw.toString())); } catch { /* ignore malformed test data */ }
    });
    socket.once('open', () => {
      clearTimeout(timer);
      resolve({ status: 'open', socket, messages });
    });
    socket.once('error', () => {
      clearTimeout(timer);
      resolve({ status: 'error', messages });
    });
  })));
  return { clients, durationMs: performance.now() - started };
}

const sockets = await openSockets();
const validSockets = sockets.clients.filter((client) => client.status === 'open');

const poolSamples = [];
const poolPolling = setInterval(async () => {
  const ready = await request('/api/health/ready');
  if (ready.body?.database?.pool) poolSamples.push(ready.body.database.pool);
}, 25);

const reservationResults = await Promise.all(Array.from({ length: reservationUsers }, (_, index) => {
  const userId = userStart + index;
  return request('/api/reservas', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${tokenFor(userId)}`,
      'content-type': 'application/json',
      'x-idempotency-key': `mixed-load-${userId}-${Date.now()}`
    },
    body: JSON.stringify({ cadeiraId: index + 1, dataReserva: reservationDate })
  });
}));

const queryResults = await Promise.all(Array.from({ length: websocketUsers }, (_, index) => {
  const token = tokenFor(userStart + index);
  return Promise.all([
    request(`/api/escritorios/${officeId}/mapa?data=${reservationDate}`, { headers: { authorization: `Bearer ${token}` } }),
    request('/api/reservas/minhas', { headers: { authorization: `Bearer ${token}` } }),
    request('/api/reservas/historico', { headers: { authorization: `Bearer ${token}` } })
  ]);
}));

await new Promise((resolve) => setTimeout(resolve, 300));
const createdReservations = reservationResults
  .filter((result) => result.status === 201 && result.body?.reserva?.id)
  .map((result) => result.body.reserva);
const cancelResults = await Promise.all(createdReservations.map((reservation) => {
  const reservationUserId = reservation.usuario_id ?? reservation.usuarioId;
  const token = tokenFor(Number(reservationUserId));
  return request(`/api/reservas/${reservation.id}`, {
    method: 'DELETE',
    headers: { authorization: `Bearer ${token}` }
  });
}));

await new Promise((resolve) => setTimeout(resolve, 300));
for (const client of validSockets) client.socket.close();
clearInterval(poolPolling);

const events = validSockets.flatMap((client) => client.messages);
const seatEvents = events.filter((event) => event.evento === 'assento_atualizado');
const validSeatEvents = seatEvents.filter((event) =>
  Number(event.escritorioId) === officeId &&
  Number(event.cadeiraId) >= 1 &&
  typeof event.data === 'string' &&
  typeof event.status === 'string'
);
const maxWaitingCount = Math.max(0, ...poolSamples.map((sample) => sample.waitingCount || 0));

console.log(JSON.stringify({
  configuration: { websocketUsers, reservationUsers, officeId, reservationDate },
  websockets: {
    opened: validSockets.length,
    failed: sockets.clients.length - validSockets.length,
    openDurationMs: Math.round(sockets.durationMs),
    seatEventsReceived: seatEvents.length,
    validSeatEvents: validSeatEvents.length
  },
  reservations: latencySummary(reservationResults),
  reservationsCreated: createdReservations.length,
  cancellations: latencySummary(cancelResults),
  queries: latencySummary(queryResults.flat()),
  pool: { samples: poolSamples.length, maxWaitingCount },
  errors5xx: [...reservationResults, ...cancelResults, ...queryResults.flat()].filter((result) => result.status >= 500).length
}, null, 2));