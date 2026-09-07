import { Request, Response } from 'express';
import pool from '../config/db';
import { logger } from '../utils/logger';

export class HealthController {
  /**
   * Sonda de Liveness (K8s / Load Balancer)
   * Verifica se o processo Node.js está responsivo.
   */
  static async live(req: Request, res: Response) {
    const mem = process.memoryUsage();
    res.status(200).json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptimeSeconds: Math.floor(process.uptime()),
      memory: {
        rssMb: Math.round((mem.rss / 1024 / 1024) * 100) / 100,
        heapUsedMb: Math.round((mem.heapUsed / 1024 / 1024) * 100) / 100,
        heapTotalMb: Math.round((mem.heapTotal / 1024 / 1024) * 100) / 100
      },
      service: 'seatmap-backend'
    });
  }

  /**
   * Sonda de Readiness (K8s / Load Balancer)
   * Valida se a aplicação e suas dependências vitais (PostgreSQL) estão prontas para receber tráfego.
   */
  static async ready(req: Request, res: Response) {
    const startTime = process.hrtime();
    const correlationId = req.correlationId;

    try {
      // Query ping no PostgreSQL
      const result = await pool.query('SELECT 1 AS ready, NOW() AS db_time');
      const diff = process.hrtime(startTime);
      const latencyMs = Math.round((diff[0] * 1e3 + diff[1] * 1e-6) * 100) / 100;

      const poolStats = {
        totalCount: pool.totalCount,
        idleCount: pool.idleCount,
        waitingCount: pool.waitingCount
      };

      res.status(200).json({
        status: 'ready',
        timestamp: new Date().toISOString(),
        database: {
          status: 'connected',
          latencyMs,
          dbTime: result.rows[0]?.db_time,
          pool: poolStats
        },
        uptimeSeconds: Math.floor(process.uptime()),
        service: 'seatmap-backend'
      });
    } catch (error: any) {
      const diff = process.hrtime(startTime);
      const latencyMs = Math.round((diff[0] * 1e3 + diff[1] * 1e-6) * 100) / 100;

      logger.error('Falha na sonda de prontidão (Readiness Probe): Banco de Dados inoperante', {
        correlationId,
        error: error.message,
        latencyMs
      });

      res.status(503).json({
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        database: {
          status: 'disconnected',
          latencyMs,
          error: error.message
        },
        service: 'seatmap-backend'
      });
    }
  }

  /**
   * Endpoint de compatibilidade legado (/api/health)
   */
  static async health(req: Request, res: Response) {
    res.status(200).json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      service: 'seatmap-backend'
    });
  }
}

