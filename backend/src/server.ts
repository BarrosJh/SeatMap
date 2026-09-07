import express from 'express';
import http from 'http';
import dotenv from 'dotenv';
import cors from 'cors';
import routes from './routes';
import { wsManager } from './websocket/wsServer';
import { CronService } from './services/cronService';
import { globalLimiter } from './middleware/rateLimiter';
import { validateSecurityConfig } from './config/securityValidation';

dotenv.config();
validateSecurityConfig();

const app = express();
app.set('trust proxy', true);
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
  allowedHeaders: ['Content-Type', 'Authorization', 'x-admin-token']
}));
app.use(express.json());

// Rate Limiting Global
app.use('/api', globalLimiter);

// Rotas da API
app.use('/api', routes);

// Health Check
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    service: 'seatmap-backend'
  });
});

// Inicializar WebSocket nativo
wsManager.init(server);

// Inicializar Agendador No-Show (Cron)
CronService.init();

const PORT = process.env.PORT || 3000;

if (process.env.NODE_ENV !== 'test') {
  server.listen(PORT, () => {
    console.log(`[SeatMap API] Servidor Express ativo em http://localhost:${PORT}`);
    console.log(`[SeatMap API] WebSocket ativo em ws://localhost:${PORT}/ws`);
  });
}

export { app, server };
