import fs from 'fs';
import path from 'path';
import express from 'express';
import http from 'http';
import dotenv from 'dotenv';
import cors from 'cors';
import helmet from 'helmet';
import routes from './routes';
import { wsManager } from './websocket/wsServer';
import { CronService } from './services/cronService';
import { AuditService } from './services/auditService';
import { globalLimiter } from './middleware/rateLimiter';
import { validateSecurityConfig } from './config/securityValidation';
import { correlationIdMiddleware } from './middleware/correlationId';
import { requestLoggerMiddleware } from './middleware/requestLogger';
import { errorHandler } from './middleware/errorHandler';
import { logger } from './utils/logger';
import pool from './config/db';
import { MetricsService } from './services/metricsService';

dotenv.config();
validateSecurityConfig();

const app = express();
const trustProxyHops = Number.parseInt(process.env.TRUST_PROXY_HOPS || '0', 10);
app.set('trust proxy', Number.isFinite(trustProxyHops) && trustProxyHops > 0 ? trustProxyHops : false);

// Injeção de X-Correlation-ID em todas as requisições antes de qualquer outro middleware
app.use(correlationIdMiddleware);

// Hardening de Segurança HTTP (Anti-Clickjacking, Anti-MIME-Sniffing, HSTS, CSP)
app.use(helmet({
  frameguard: { action: 'deny' },
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", 'data:', 'https:'],
      connectSrc: ["'self'", 'ws:', 'wss:']
    }
  },
  crossOriginEmbedderPolicy: false,
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));
app.disable('x-powered-by');

const server = http.createServer(app);

// Configuração segura de CORS
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim())
  : ['http://localhost:3000', 'http://localhost:8080', 'http://127.0.0.1:3000', 'http://127.0.0.1:8080'];

app.use(cors({
  origin: (origin, callback) => {
    // Permite chamadas sem origin (mobile apps, curl, server-to-server) e origens permitidas
    if (!origin || allowedOrigins.includes(origin) || process.env.NODE_ENV !== 'production') {
      callback(null, true);
    } else {
      callback(new Error('Origem não permitida pela política de CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-admin-token', 'x-correlation-id', 'x-request-id'],
  exposedHeaders: ['X-Correlation-Id']
}));
app.use(express.json({
  limit: '256kb',
  type: ['application/json', 'application/scim+json', 'application/*+json']
}));

// Logger Estruturado de Requisições HTTP (SIEM / SOC)
app.use(requestLoggerMiddleware);

// Servir Aplicação Flutter Web (Frontend Monolith) se a pasta public existir
const publicPath = path.join(__dirname, '../public');
if (fs.existsSync(publicPath)) {
  app.use(express.static(publicPath));
} else {
  // Rota Raiz para Health Check do Load Balancer / Render quando rodando sem frontend embutido
  app.get('/', (req, res) => {
    res.status(200).json({
      status: 'online',
      service: 'SeatMap API Enterprise',
      version: '1.0.0',
      timestamp: new Date().toISOString()
    });
  });
}

// Rotas da API
app.use('/api', routes);

// Fallback SPA para navegação do Flutter Web
if (fs.existsSync(publicPath)) {
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api') || req.path.startsWith('/ws')) return next();
    res.sendFile(path.join(publicPath, 'index.html'));
  });
}

// Middleware Global de Tratamento de Erros (AppSec / SIEM / AppError / Zod)
app.use(errorHandler);


// Inicializar WebSocket nativo
wsManager.init(server);

// Inicializar Agendador No-Show (Cron)
CronService.init();

const PORT = process.env.PORT || 3000;

if (process.env.NODE_ENV !== 'test') {
  server.listen(PORT, () => {
    logger.info(`[SeatMap API] Servidor Express ativo em http://localhost:${PORT}`, { port: PORT });
    logger.info(`[SeatMap API] WebSocket ativo em ws://localhost:${PORT}/ws`);
  });
}

// ==========================================
// Graceful Shutdown & Process Lifecycle
// ==========================================
let isShuttingDown = false;

export const gracefulShutdown = async (signal: string): Promise<void> => {
  if (isShuttingDown) return;
  isShuttingDown = true;

  logger.info(`[SeatMap API] Recebido sinal ${signal}. Iniciando encerramento gracioso...`);

  // Timeout de segurança para forçar encerramento caso conexões fiquem pendentes
  const forceExitTimeout = setTimeout(() => {
    logger.error('[SeatMap API] Encerramento forçado após timeout de 10s.');
    if (process.env.NODE_ENV !== 'test') {
      process.exit(1);
    }
  }, 10000);
  if (typeof forceExitTimeout.unref === 'function') {
    forceExitTimeout.unref();
  }

  try {
    // 1. Aguardar conclusão de tarefas Cron em andamento e parar agendador
    await CronService.waitForCompletion(5000);

    // 2. Encerrar conexões WebSocket ativas
    wsManager.destroy();

    // 3. Fechar servidor HTTP Express
    await new Promise<void>((resolve, reject) => {
      server.close((err) => {
        if (err) return reject(err);
        resolve();
      });
    });
    logger.info('[SeatMap API] Servidor HTTP Express encerrado com sucesso.');

    // 4. Esvaziar buffer de auditoria persistindo logs pendentes
    await AuditService.shutdown();
    logger.info('[SeatMap API] Buffer de auditoria descarregado com sucesso.');

    // 5. Drenar e fechar o pool de conexões do PostgreSQL
    await pool.end();
    logger.info('[SeatMap API] Pool PostgreSQL drenado e finalizado.');

    clearTimeout(forceExitTimeout);
    logger.info('[SeatMap API] Encerramento gracioso finalizado com sucesso.');

    if (process.env.NODE_ENV !== 'test') {
      process.exit(0);
    }
  } catch (error) {
    logger.error('[SeatMap API] Erro durante o encerramento gracioso:', { error });
    if (process.env.NODE_ENV !== 'test') {
      process.exit(1);
    }
  }
};

if (process.env.NODE_ENV !== 'test') {
  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));

  process.on('unhandledRejection', (reason: any) => {
    MetricsService.recordProcessFailure('UNHANDLED_REJECTION', { reason: reason instanceof Error ? reason.message : String(reason) });
    logger.error('[SeatMap API - Unhandled Rejection]', { reason: reason instanceof Error ? reason.stack : reason });
  });

  process.on('uncaughtException', (error: Error) => {
    MetricsService.recordProcessFailure('UNCAUGHT_EXCEPTION', { error: error.message });
    logger.error('[SeatMap API - Uncaught Exception]', { error: error.stack });
    gracefulShutdown('uncaughtException');
  });
}

export { app, server };
