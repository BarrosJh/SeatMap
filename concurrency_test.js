import http from 'k6/http';
import { check } from 'k6';
import { Counter, Rate } from 'k6/metrics';

const reservationSuccesses = new Counter('reservation_successes');
const reservationSuccessRate = new Rate('reservation_success_rate');

export const options = {
  vus: Number(__ENV.VUS || 2),
  iterations: Number(__ENV.ITERATIONS || 2),
  thresholds: {
    reservation_success_rate: ['rate==0.5'],
    http_req_failed: ['rate<0.5']
  }
};

const baseUrl = (__ENV.BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
const token = __ENV.AUTH_TOKEN;
const cadeiraId = Number(__ENV.SEAT_ID);
const dataReserva = __ENV.RESERVATION_DATE;

if (!token || !Number.isInteger(cadeiraId) || cadeiraId <= 0 || !/^\d{4}-\d{2}-\d{2}$/.test(dataReserva || '')) {
  throw new Error('Defina BASE_URL, AUTH_TOKEN, SEAT_ID e RESERVATION_DATE (YYYY-MM-DD).');
}

export default function () {
  const response = http.post(
    `${baseUrl}/api/reservas`,
    JSON.stringify({ cadeiraId, dataReserva }),
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
        'X-Correlation-Id': `k6-concurrency-${__VU}-${__ITER}`,
        'X-Idempotency-Key': `k6-concurrency-${__VU}-${__ITER}`
      },
      tags: { scenario: 'same-seat-concurrency' }
    }
  );

  const succeeded = response.status >= 200 && response.status < 300;
  reservationSuccessRate.add(succeeded);
  if (succeeded) reservationSuccesses.add(1);

  check(response, {
    'exactly one request succeeds or conflict is returned': (result) =>
      (result.status >= 200 && result.status < 300) || result.status === 400 || result.status === 409
  });
}

export function handleSummary(data) {
  return {
    stdout: JSON.stringify({
      scenario: 'same-seat-concurrency',
      reservationSuccesses: data.metrics.reservation_successes?.values?.count || 0,
      reservationSuccessRate: data.metrics.reservation_success_rate?.values?.rate || 0
    }, null, 2) + '\n'
  };
}