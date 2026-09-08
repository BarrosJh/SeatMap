const baseUrl = (process.env.BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
const userStart = Number(process.env.LOAD_USER_ID_START || 9);
const users = Number(process.env.USERS || 300);
const password = process.env.LOAD_TEST_PASSWORD || 'Carga@2026!';

const started = performance.now();
const responses = await Promise.all(Array.from({ length: users }, (_, index) => {
  const sequence = String(index + 1).padStart(3, '0');
  return fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ login: `carga${sequence}@loadtest.local`, senha: password })
  }).then(async (response) => ({
    status: response.status,
    durationMs: performance.now() - started,
    body: await response.json().catch(() => undefined)
  })).catch((error) => ({ status: 0, durationMs: performance.now() - started, error: String(error) }));
}));

const durations = responses.map((response) => response.durationMs).sort((a, b) => a - b);
const percentile = (value) => durations[Math.min(durations.length - 1, Math.ceil(durations.length * value / 100) - 1)] || 0;
console.log(JSON.stringify({
  total: users,
  statuses: responses.reduce((result, response) => {
    result[response.status] = (result[response.status] || 0) + 1;
    return result;
  }, {}),
  p50Ms: Math.round(percentile(50) * 100) / 100,
  p95Ms: Math.round(percentile(95) * 100) / 100,
  p99Ms: Math.round(percentile(99) * 100) / 100,
  errors: responses.filter((response) => response.status >= 500 || response.status === 0).length
}, null, 2));