import { logger } from '../utils/logger';

interface RouteMetric {
  requests: number;
  errors4xx: number;
  errors5xx: number;
  totalDurationMs: number;
  maxDurationMs: number;
  samples: number[];
}

export interface MetricsSnapshot {
  generatedAt: string;
  process: {
    uptimeSeconds: number;
    activeRequests: number;
    memory: {
      rssMb: number;
      heapUsedMb: number;
      heapTotalMb: number;
    };
  };
  requests: {
    total: number;
    errors4xx: number;
    errors5xx: number;
    errorRatePercent: number;
    averageLatencyMs: number;
    p95LatencyMs: number;
  };
  routes: Array<{
    route: string;
    requests: number;
    errors4xx: number;
    errors5xx: number;
    averageLatencyMs: number;
    p95LatencyMs: number;
    maxDurationMs: number;
  }>;
  alerts: Array<{
    type: string;
    message: string;
    createdAt: string;
  }>;
}

export class MetricsService {
  private static readonly MAX_ROUTE_SAMPLES = 500;
  private static readonly MAX_ALERTS = 50;
  private static readonly ALERT_COOLDOWN_MS = 60_000;
  private static readonly routes = new Map<string, RouteMetric>();
  private static readonly latencySamples: number[] = [];
  private static readonly alerts: MetricsSnapshot['alerts'] = [];
  private static totalRequests = 0;
  private static total4xx = 0;
  private static total5xx = 0;
  private static activeRequests = 0;
  private static totalDurationMs = 0;
  private static lastCriticalAlertAt = 0;

  public static requestStarted(): void {
    this.activeRequests += 1;
  }

  public static requestFinished(route: string, statusCode: number, durationMs: number): void {
    this.activeRequests = Math.max(0, this.activeRequests - 1);
    this.totalRequests += 1;
    this.totalDurationMs += durationMs;

    if (statusCode >= 500) this.total5xx += 1;
    else if (statusCode >= 400) this.total4xx += 1;

    this.pushSample(this.latencySamples, durationMs);

    const metric = this.routes.get(route) || {
      requests: 0,
      errors4xx: 0,
      errors5xx: 0,
      totalDurationMs: 0,
      maxDurationMs: 0,
      samples: []
    };
    metric.requests += 1;
    metric.totalDurationMs += durationMs;
    metric.maxDurationMs = Math.max(metric.maxDurationMs, durationMs);
    if (statusCode >= 500) metric.errors5xx += 1;
    else if (statusCode >= 400) metric.errors4xx += 1;
    this.pushSample(metric.samples, durationMs);
    this.routes.set(route, metric);

    if (statusCode >= 500) {
      this.alert('HTTP_5XX', `Falha HTTP 5xx detectada em ${route}`, {
        route,
        statusCode,
        durationMs
      });
    }

    if (durationMs >= 2000) {
      this.alert('SLOW_REQUEST', `Requisição lenta detectada em ${route}`, {
        route,
        statusCode,
        durationMs
      });
    }

    if (this.activeRequests >= 100) {
      this.alert('HIGH_CONCURRENCY', 'Número elevado de requisições simultâneas', {
        activeRequests: this.activeRequests
      });
    }
  }

  public static recordDependencyFailure(dependency: string, details?: Record<string, unknown>): void {
    this.alert('DEPENDENCY_FAILURE', `Falha crítica na dependência ${dependency}`, details);
  }

  public static recordProcessFailure(type: 'UNHANDLED_REJECTION' | 'UNCAUGHT_EXCEPTION', details?: Record<string, unknown>): void {
    this.alert(type, `Falha crítica de processo: ${type}`, details);
  }

  public static getSnapshot(): MetricsSnapshot {
    const memory = process.memoryUsage();
    const routes = Array.from(this.routes.entries())
      .map(([route, metric]) => ({
        route,
        requests: metric.requests,
        errors4xx: metric.errors4xx,
        errors5xx: metric.errors5xx,
        averageLatencyMs: this.round(metric.totalDurationMs / metric.requests),
        p95LatencyMs: this.percentile(metric.samples, 95),
        maxDurationMs: this.round(metric.maxDurationMs)
      }))
      .sort((a, b) => b.requests - a.requests)
      .slice(0, 50);

    return {
      generatedAt: new Date().toISOString(),
      process: {
        uptimeSeconds: Math.floor(process.uptime()),
        activeRequests: this.activeRequests,
        memory: {
          rssMb: this.round(memory.rss / 1024 / 1024),
          heapUsedMb: this.round(memory.heapUsed / 1024 / 1024),
          heapTotalMb: this.round(memory.heapTotal / 1024 / 1024)
        }
      },
      requests: {
        total: this.totalRequests,
        errors4xx: this.total4xx,
        errors5xx: this.total5xx,
        errorRatePercent: this.round(this.totalRequests === 0 ? 0 : ((this.total4xx + this.total5xx) / this.totalRequests) * 100),
        averageLatencyMs: this.round(this.totalRequests === 0 ? 0 : this.totalDurationMs / this.totalRequests),
        p95LatencyMs: this.percentile(this.latencySamples, 95)
      },
      routes,
      alerts: [...this.alerts]
    };
  }

  public static resetForTests(): void {
    this.routes.clear();
    this.latencySamples.length = 0;
    this.alerts.length = 0;
    this.totalRequests = 0;
    this.total4xx = 0;
    this.total5xx = 0;
    this.activeRequests = 0;
    this.totalDurationMs = 0;
    this.lastCriticalAlertAt = 0;
  }

  private static alert(type: string, message: string, details?: Record<string, unknown>): void {
    const now = Date.now();
    const createdAt = new Date(now).toISOString();
    this.alerts.unshift({ type, message, createdAt });
    if (this.alerts.length > this.MAX_ALERTS) this.alerts.pop();

    if (now - this.lastCriticalAlertAt >= this.ALERT_COOLDOWN_MS) {
      this.lastCriticalAlertAt = now;
      logger.error(`[ALERT] ${message}`, { alertType: type, ...details });
    }
  }

  private static pushSample(samples: number[], value: number): void {
    samples.push(value);
    if (samples.length > this.MAX_ROUTE_SAMPLES) samples.shift();
  }

  private static percentile(samples: number[], percentile: number): number {
    if (samples.length === 0) return 0;
    const sorted = [...samples].sort((a, b) => a - b);
    const index = Math.min(sorted.length - 1, Math.ceil((percentile / 100) * sorted.length) - 1);
    return this.round(sorted[Math.max(0, index)]);
  }

  private static round(value: number): number {
    return Math.round(value * 100) / 100;
  }
}