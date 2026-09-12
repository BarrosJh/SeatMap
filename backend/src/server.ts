import fs from 'fs';
import path from 'path';
import dns from 'dns';
import express from 'express';

if (typeof dns.setDefaultResultOrder === 'function') {
  dns.setDefaultResultOrder('ipv4first');
}
import http from 'http';
import dotenv from 'dotenv';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
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

// Hardening de Segurança HTTP (Anti-Clickjacking, Anti-MIME-Sniffing, HSTS, COEP, CSP Estrita com Report-URI)
app.use(helmet({
  frameguard: { action: 'deny' },
  referrerPolicy: { policy: 'no-referrer' },
  xssFilter: false, // Desativado no helmet para usar o header estrito explícito abaixo
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'wasm-unsafe-eval'", "'unsafe-inline'", 'https://unpkg.com'],
      scriptSrcElem: ["'self'", "'unsafe-inline'", 'https://unpkg.com'],
      styleSrc: ["'self'", 'https://fonts.googleapis.com', "'unsafe-inline'"],
      fontSrc: ["'self'", 'https://fonts.gstatic.com', 'data:'],
      imgSrc: ["'self'", 'data:', 'https:', 'blob:'],
      mediaSrc: ["'self'", 'blob:', 'data:'],
      connectSrc: ["'self'", 'wss:', 'https:', 'https://unpkg.com'],
      workerSrc: ["'self'", 'blob:'],
      objectSrc: ["'none'"],
      upgradeInsecureRequests: [],
      reportUri: '/api/csp-report'
    }
  },
  crossOriginEmbedderPolicy: { policy: 'credentialless' },
  crossOriginOpenerPolicy: { policy: 'same-origin' },
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));
app.disable('x-powered-by');

// Cabeçalhos HTTP Mandatórios 
app.use((req, res, next) => {
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.removeHeader('Server');
  res.removeHeader('X-Powered-By');
  next();
});

const server = http.createServer(app);

// Configuração segura de CORS (Sem wildcard aberto em produção/staging, com suporte a self-host e Render)
const isProduction = ['production', 'staging'].includes((process.env.NODE_ENV || 'development').toLowerCase());
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim())
  : (isProduction ? [] : ['*']);

app.use(cors((req, callback) => {
  const origin = req.headers.origin;
  // Permite chamadas sem origin (mobile apps nativos, curl, health probes internos)
  if (!origin) {
    return callback(null, { origin: true, credentials: true });
  }

  const host = req.headers.host;
  const forwardedHost = req.headers['x-forwarded-host'] as string | undefined;

  let isAllowed = false;

  if (!isProduction && (allowedOrigins.includes('*') || origin.endsWith('.onrender.com') || origin.includes('localhost') || origin.includes('127.0.0.1'))) {
    isAllowed = true;
  } else if (allowedOrigins.includes(origin)) {
    isAllowed = true;
  } else if (process.env.RENDER_EXTERNAL_URL && origin === process.env.RENDER_EXTERNAL_URL.replace(/\/$/, '')) {
    isAllowed = true;
  } else if (process.env.APP_URL && origin === process.env.APP_URL.replace(/\/$/, '')) {
    isAllowed = true;
  } else {
    try {
      const parsedOrigin = new URL(origin);
      if (host && (parsedOrigin.host === host || (forwardedHost && parsedOrigin.host === forwardedHost))) {
        isAllowed = true;
      }
    } catch {
      isAllowed = false;
    }
  }

  callback(null, {
    origin: isAllowed,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'x-admin-token', 'x-correlation-id', 'x-request-id'],
    exposedHeaders: ['X-Correlation-Id', 'RateLimit-Limit', 'RateLimit-Remaining', 'RateLimit-Reset', 'Retry-After']
  });
}));
app.use(express.json({
  limit: '256kb',
  type: ['application/json', 'application/scim+json', 'application/csp-report', 'application/*+json']
}));

// Rate Limiter Global para mitigação de DoS e proteção de todas as rotas
app.use(globalLimiter);

// Logger Estruturado de Requisições HTTP (SIEM / SOC)
app.use(requestLoggerMiddleware);

// Headers de Segurança, Anti-Cache e Permissions-Policy para todas as rotas de API
app.use('/api', (req, res, next) => {
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=(), usb=()');
  next();
});

// Permissions-Policy e Headers para o PWA (Câmera liberada para QR Code scanner na própria aplicação)
app.use((req, res, next) => {
  if (!req.path.startsWith('/api')) {
    const extraOrigin = process.env.RENDER_EXTERNAL_URL || process.env.APP_URL;
    const cameraOrigin = extraOrigin ? `(self "${extraOrigin.replace(/\/$/, '')}")` : '(self)';
    const cameraFeatureOrigin = extraOrigin ? `'self' ${extraOrigin.replace(/\/$/, '')}` : "'self'";
    res.setHeader('Permissions-Policy', `camera=${cameraOrigin}, microphone=(), geolocation=(), payment=(), usb=()`);
    res.setHeader('Feature-Policy', `camera ${cameraFeatureOrigin}; microphone 'none'; geolocation 'none'`);
  }
  next();
});

// Ativa Compressão HTTP (Gzip/Deflate) para acelerar a transferência de bundles e WASM
app.use(compression());

// Servir Aplicação Flutter Web (Frontend Monolith) se a pasta public existir
const publicPath = path.join(__dirname, '../public');
if (fs.existsSync(publicPath)) {
  app.use(express.static(publicPath, {
    maxAge: '1y',
    immutable: true,
    setHeaders: (res, filePath) => {
      if (filePath.endsWith('.wasm')) {
        res.setHeader('Content-Type', 'application/wasm');
      }
      // index.html e service worker sempre revalidados para deploy instantâneo
      if (filePath.endsWith('index.html') || filePath.endsWith('sw.js') || filePath.endsWith('flutter_bootstrap.js') || filePath.endsWith('flutter_service_worker.js')) {
        res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        res.setHeader('Pragma', 'no-cache');
        res.setHeader('Expires', '0');
      }
    }
  }));
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
