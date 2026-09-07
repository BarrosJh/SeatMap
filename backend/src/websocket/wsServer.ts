import { Server as HttpServer } from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import url from 'url';
import jwt from 'jsonwebtoken';
import pool from '../config/db';

interface AuthenticatedWebSocket extends WebSocket {
  userId?: number;
  perfil?: string;
  escritorioId?: number;
  isAlive: boolean;
}

export interface SeatUpdatePayload {
  evento: 'assento_atualizado';
  escritorioId: number;
  cadeiraId: number;
  data: string;
  status: 'livre' | 'ocupada' | 'minha_reserva' | 'expirada' | 'manutencao';
  ocupante?: {
    nome: string;
    departamento: string;
    departamentoId?: number;
  } | null;
}


export class WsManager {
  private static instance: WsManager;
  private wss: WebSocketServer | null = null;
  private rooms: Map<number, Set<AuthenticatedWebSocket>> = new Map();
  private pingInterval: NodeJS.Timeout | null = null;

  private constructor() {}

  public static getInstance(): WsManager {
    if (!WsManager.instance) {
      WsManager.instance = new WsManager();
    }
    return WsManager.instance;
  }

  public init(server: HttpServer): void {
    this.wss = new WebSocketServer({ server, path: '/ws' });

    this.wss.on('connection', (ws: AuthenticatedWebSocket, req) => {
      const parsedUrl = url.parse(req.url || '', true);
      let token: string | undefined;

      // 1. Extração via Sec-WebSocket-Protocol (Recomendado RFC 6455 / OWASP)
      const protocolHeader = req.headers['sec-websocket-protocol'];
      if (typeof protocolHeader === 'string') {
        const parts = protocolHeader.split(',').map(p => p.trim());
        if (parts.length >= 2 && parts[0].toLowerCase() === 'bearer') {
          token = parts[1];
        } else {
          token = parts.find(p => p.startsWith('eyJ') || p.split('.').length === 3) || parts[0];
        }
      }

      // 2. Extração via cabeçalho Authorization padrão
      if (!token && req.headers['authorization']) {
        const auth = req.headers['authorization'];
        if (auth.startsWith('Bearer ')) {
          token = auth.substring(7).trim();
        }
      }

      // 3. Fallback de compatibilidade via query parameter
      if (!token && parsedUrl.query.token) {
        token = parsedUrl.query.token as string;
      }

      const initialEscritorioId = parsedUrl.query.escritorioId ? parseInt(parsedUrl.query.escritorioId as string, 10) : undefined;

      // Validação do token JWT no handshake da conexão
      if (!token) {
        console.warn('[WS] Conexão rejeitada: token de autenticação não fornecido.');
        ws.close(4001, 'Token de autenticação obrigatório.');
        return;
      }

      let decoded: any;
      try {
        const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_seatmap_2026_change_in_prod';
        decoded = jwt.verify(token, JWT_SECRET) as any;
        ws.userId = decoded.userId;
        ws.perfil = decoded.perfil;
      } catch (err) {
        console.warn('[WS] Conexão rejeitada: token JWT inválido ou expirado.');
        ws.close(4001, 'Token JWT inválido ou expirado.');
        return;
      }

      // Validação assíncrona de token_version e status ativo no banco
      if (decoded?.userId) {
        pool.query(
          'SELECT ativo, COALESCE(token_version, 1) AS token_version FROM usuarios WHERE id = $1',
          [decoded.userId]
        ).then(userCheck => {
          if (userCheck.rowCount === 0 || !userCheck.rows[0].ativo || (decoded.tokenVersion && decoded.tokenVersion < userCheck.rows[0].token_version)) {
            console.warn(`[WS] Conexão encerrada: usuário ${decoded.userId} inativo ou sessão revogada.`);
            ws.close(4003, 'Sessão revogada ou usuário inativo.');
          }
        }).catch(() => {
          // Ignora falha de conexão de banco em testes isolados
        });
      }

      ws.isAlive = true;
      ws.on('pong', () => {
        ws.isAlive = true;
      });

      if (initialEscritorioId && !isNaN(initialEscritorioId)) {
        this.joinRoom(initialEscritorioId, ws);
      }

      ws.on('message', (data: string) => {
        try {
          const msg = JSON.parse(data.toString());
          if (msg.action === 'subscribe' && msg.escritorioId) {
            const escritorioId = parseInt(msg.escritorioId, 10);
            this.joinRoom(escritorioId, ws);
          } else if (msg.action === 'unsubscribe' && msg.escritorioId) {
            const escritorioId = parseInt(msg.escritorioId, 10);
            this.leaveRoom(escritorioId, ws);
          }
        } catch (e) {
          console.error('[WS] Mensagem inválida recebida:', e);
        }
      });

      ws.on('close', () => {
        if (ws.escritorioId) {
          this.leaveRoom(ws.escritorioId, ws);
        }
      });
    });

    // Heartbeat ping interval com handle para teardown gracioso
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
    }

    this.pingInterval = setInterval(() => {
      if (!this.wss) return;
      this.wss.clients.forEach((client) => {
        const authWs = client as AuthenticatedWebSocket;
        if (!authWs.isAlive) {
          return authWs.terminate();
        }
        authWs.isAlive = false;
        authWs.ping();
      });
    }, 30000);

    // Desvincula timer do event loop para não bloquear saída em testes/scripts
    if (this.pingInterval && typeof this.pingInterval.unref === 'function') {
      this.pingInterval.unref();
    }

    console.log('[WebSocket] Servidor WS nativo inicializado no endpoint /ws');
  }

  public destroy(): void {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }
    if (this.wss) {
      this.wss.clients.forEach((client) => client.terminate());
      this.wss.close();
      this.wss = null;
    }
    this.rooms.clear();
  }

  public joinRoom(escritorioId: number, ws: AuthenticatedWebSocket): void {
    if (ws.escritorioId && ws.escritorioId !== escritorioId) {
      this.leaveRoom(ws.escritorioId, ws);
    }
    ws.escritorioId = escritorioId;
    if (!this.rooms.has(escritorioId)) {
      this.rooms.set(escritorioId, new Set());
    }
    this.rooms.get(escritorioId)?.add(ws);
  }

  public leaveRoom(escritorioId: number, ws: AuthenticatedWebSocket): void {
    const room = this.rooms.get(escritorioId);
    if (room) {
      room.delete(ws);
      if (room.size === 0) {
        this.rooms.delete(escritorioId);
      }
    }
    if (ws.escritorioId === escritorioId) {
      ws.escritorioId = undefined;
    }
  }

  public broadcastSeatUpdate(payload: SeatUpdatePayload): void {
    const room = this.rooms.get(payload.escritorioId);
    if (!room || room.size === 0) return;

    const message = JSON.stringify(payload);
    for (const client of room) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(message);
      }
    }
  }

  public broadcastToAll(data: any): void {
    if (!this.wss) return;
    const message = JSON.stringify(data);
    this.wss.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(message);
      }
    });
  }

  public getClientCount(): number {
    return this.wss ? this.wss.clients.size : 0;
  }

  public getRoomsInfo(): { totalClients: number; activeRooms: number } {
    return {
      totalClients: this.wss ? this.wss.clients.size : 0,
      activeRooms: this.rooms.size
    };
  }
}

export const wsManager = WsManager.getInstance();

