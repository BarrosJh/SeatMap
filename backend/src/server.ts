import express from 'express';
import http from 'http';
import dotenv from 'dotenv';
import cors from 'cors';
import routes from './routes';
import { wsManager } from './websocket/wsServer';
import { CronService } from './services/cronService';

dotenv.config();

const app = express();
const server = http.createServer(app);

// Middlewares globais
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-admin-token']
}));
app.use(express.json());

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
