import express from 'express';
import http from 'http';
import dotenv from 'dotenv';
import cors from 'cors';
import helmet from 'helmet';
import routes from './routes';
import { wsManager } from './websocket/wsServer';
import { CronService } from './services/cronService';
import { globalLimiter } from './middleware/rateLimiter';
import { validateSecurityConfig } from './config/securityValidation';
import { correlationIdMiddleware } from './middleware/correlationId';
import { requestLoggerMiddleware } from './middleware/requestLogger';
import { logger } from './utils/logger';

dotenv.config();
validateSecurityConfig();

const app = express();
app.set('trust proxy', true);

// Injeção de X-Correlation-ID em todas as requisições antes de qualquer outro middleware
app.use(correlationIdMiddleware);

// Hardening de Segurança HTTP (Anti-Clickjacking, Anti-MIME-Sniffing, HSTS)
app.use(helmet({
  frameguard: { action: 'deny' },
  contentSecurityPolicy: false, // Permite que a API sirva endpoints REST e SPA
  crossOriginEmbedderPolicy: false,
  hsts: process.env.NODE_ENV === 'production' ? { maxAge: 31536000, includeSubDomains: true } : false
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
  type: ['application/json', 'application/scim+json', 'application/*+json']
}));

// Logger Estruturado de Requisições HTTP (SIEM / SOC)
app.use(requestLoggerMiddleware);

// Rate Limiting Global
app.use('/api', globalLimiter);

// Rotas da API
app.use('/api', routes);

// Middleware Global de Tratamento de Erros (AppSec / SIEM)
app.use((err: any, req: express.Request, res: express.Response, _next: express.NextFunction) => {
  const rawCorr = req.correlationId || req.headers['x-correlation-id'] || 'unknown';
  const correlationId = Array.isArray(rawCorr) ? rawCorr[0] : String(rawCorr);
  const reqLogger = req.logger || logger;

  reqLogger.error(`[Unhandled Server Error] ${err.message || err}`, {
    correlationId,
    path: req.originalUrl || req.path,
    method: req.method,
    stack: process.env.NODE_ENV !== 'production' ? err.stack : undefined
  });

  const statusCode = typeof err.statusCode === 'number' ? err.statusCode : (typeof err.status === 'number' ? err.status : 500);

  if (!res.headersSent) {
    res.status(statusCode).json({
      error: statusCode >= 500 && process.env.NODE_ENV === 'production'
        ? 'Erro interno do servidor. Entre em contato com o suporte.'
        : (err.message || 'Erro inesperado no processamento da requisição.'),
      correlationId
    });
  }
});

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

export { app, server };
