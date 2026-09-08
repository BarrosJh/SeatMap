import { spawn } from 'node:child_process';
import WebSocket from '../backend/node_modules/ws/index.js';
import jwt from '../backend/node_modules/jsonwebtoken/index.js';

const baseUrl = (process.env.BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
const wsUrl = baseUrl.replace(/^http/, 'ws');
const total = Number(process.env.WS_USERS || 300);
const userStart = Number(process.env.LOAD_USER_ID_START || 9);
const officeId = Number(process.env.OFFICE_ID || 1);
const secret = process.env.DEV_JWT_SECRET || 'dev_local_secret_key_for_jwt_secret_32chars_len';
const deadlineMs = Number(process.env.RECONNECT_DEADLINE_MS || 20000);

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

function openClient(userId, state, startedAt) {
  return new Promise((resolve) => {
    const socket = new WebSocket(`${wsUrl}/ws?escritorioId=${officeId}`, ['Bearer', tokenFor(userId)]);
    let settled = false;
    const finish = (result) => {
      if (settled) return;
      settled = true;
      resolve(result);
    };
    const timer = setTimeout(() => {
      socket.terminate();
      finish(false);
    }, 10000);
    socket.once('open', () => {
      clearTimeout(timer);
      state.opens += 1;
      state.lastOpenedAt = Date.now();
      state.socket = socket;
      finish(true);
    });
    socket.once('error', () => {
      clearTimeout(timer);
      finish(false);
    });
    socket.on('close', () => {
      if (Date.now() - startedAt < deadlineMs) {
        const delay = Math.min(1000, 50 * Math.max(1, state.opens));
        setTimeout(() => openClient(userId, state, startedAt), delay);
      }
    });
  });
}

const states = Array.from({ length: total }, () => ({ opens: 0, socket: null, lastOpenedAt: 0 }));
const startedAt = Date.now();
await Promise.all(states.map((state, index) => openClient(userStart + index, state, startedAt)));
const initialOpened = states.filter((state) => state.opens >= 1).length;

await new Promise((resolve) => {
  const child = spawn('cmd.exe', ['/d', '/c', 'docker compose restart api'], { stdio: 'ignore' });
  child.once('exit', resolve);
  child.once('error', resolve);
});

while (Date.now() - startedAt < deadlineMs && states.some((state) => state.opens < 2)) {
  await new Promise((resolve) => setTimeout(resolve, 100));
}

for (const state of states) state.socket?.close();
const reconnected = states.filter((state) => state.opens >= 2);
const reconnectTimes = reconnected.map((state) => state.lastOpenedAt - startedAt);

console.log(JSON.stringify({
  total,
  initialOpened,
  reconnected: reconnected.length,
  failedToReconnect: total - reconnected.length,
  deadlineMs,
  reconnectP50Ms: percentile(reconnectTimes, 50),
  reconnectP95Ms: percentile(reconnectTimes, 95),
  reconnectMaxMs: reconnectTimes.length ? Math.max(...reconnectTimes) : 0
}, null, 2));

function percentile(values, percent) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.ceil(sorted.length * percent / 100) - 1)];
}