import { logger } from '../../src/utils/logger';
import { MetricsService } from '../../src/services/metricsService';

describe('Bloco 6: métricas e alertas operacionais', () => {
  beforeEach(() => {
    MetricsService.resetForTests();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('agrega requisições, erros, latência e recursos do processo', () => {
    MetricsService.requestStarted();
    MetricsService.requestFinished('/api/reservas', 200, 40);
    MetricsService.requestFinished('/api/reservas', 400, 80);
    MetricsService.requestFinished('/api/admin/relatorios', 500, 120);

    const snapshot = MetricsService.getSnapshot();

    expect(snapshot.requests.total).toBe(3);
    expect(snapshot.requests.errors4xx).toBe(1);
    expect(snapshot.requests.errors5xx).toBe(1);
    expect(snapshot.requests.averageLatencyMs).toBe(80);
    expect(snapshot.requests.p95LatencyMs).toBe(120);
    expect(snapshot.process.activeRequests).toBe(0);
    expect(snapshot.process.memory.heapUsedMb).toEqual(expect.any(Number));
    expect(snapshot.routes[0]).toEqual(expect.objectContaining({
      route: '/api/reservas',
      requests: 2
    }));
  });

  it('gera alerta estruturado para 5xx e requisição lenta', () => {
    const errorSpy = jest.spyOn(logger, 'error').mockImplementation(() => undefined);

    MetricsService.requestFinished('/api/critico', 500, 2500);

    const snapshot = MetricsService.getSnapshot();
    expect(snapshot.alerts).toEqual(expect.arrayContaining([
      expect.objectContaining({ type: 'HTTP_5XX' }),
      expect.objectContaining({ type: 'SLOW_REQUEST' })
    ]));
    expect(errorSpy).toHaveBeenCalledWith(
      expect.stringContaining('[ALERT]'),
      expect.any(Object)
    );
  });

  it('registra falha de dependência para o dashboard operacional', () => {
    MetricsService.recordDependencyFailure('postgresql', { latencyMs: 1200 });

    expect(MetricsService.getSnapshot().alerts).toEqual(expect.arrayContaining([
      expect.objectContaining({ type: 'DEPENDENCY_FAILURE' })
    ]));
  });
});