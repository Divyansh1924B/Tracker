import { IncomingMessage } from 'http';
import { WebSocket, WebSocketServer } from 'ws';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { prisma } from '../database/prisma';
import url from 'url';

interface ConnectionInfo {
  ws: WebSocket;
  userId: string;
  role: 'admin' | 'member';
  name: string;
}

const connections = new Map<string, ConnectionInfo>();

export const initWebSocketServer = (wss: WebSocketServer) => {
  wss.on('connection', async (ws: WebSocket, req: IncomingMessage) => {
    const parsedUrl = url.parse(req.url || '', true);
    const token = parsedUrl.query.token as string;

    if (!token) {
      ws.close(4001, 'Unauthorized: No token provided');
      return;
    }

    let userId: string;
    let sessionId: string;
    try {
      const decoded = jwt.verify(token, config.jwtSecret) as { userId: string; sessionId: string };
      userId = decoded.userId;
      sessionId = decoded.sessionId;
    } catch (err) {
      ws.close(4002, 'Unauthorized: Invalid token');
      return;
    }

    try {
      const user = await prisma.user.findFirst({
        where: {
          id: userId,
          deletedAt: null,
        },
      });

      if (!user) {
        ws.close(4003, 'Unauthorized: User not found');
        return;
      }

      if (user.currentSessionId !== sessionId) {
        ws.close(4004, 'Unauthorized: Session invalidated');
        return;
      }

      const role = user.role;
      const name = user.name;

      const existing = connections.get(userId);
      if (existing) {
        existing.ws.close(4005, 'Session taken over by new connection');
      }

      connections.set(userId, { ws, userId, role, name });
      console.log(`WebSocket connected: User ${name} (${role})`);

      await prisma.user.update({
        where: { id: userId },
        data: { onlineStatus: true, lastSeen: new Date() },
      });

      broadcastToAdmins({
        type: 'presence_update',
        payload: { userId, online: true, lastSeen: new Date().toISOString() },
      });

      ws.on('message', async (messageBuffer) => {
        try {
          const rawMessage = messageBuffer.toString();
          const message = JSON.parse(rawMessage);

          if (message.type === 'ping') {
            ws.send(JSON.stringify({ type: 'pong' }));
            return;
          }

          if (message.type === 'location_update' && role === 'member') {
            const {
              latitude,
              longitude,
              accuracy,
              speed,
              batteryPercentage,
              chargingStatus,
              gpsEnabled,
              internetAvailable,
              timestamp,
            } = message.payload;

            await prisma.location.create({
              data: {
                userId,
                latitude,
                longitude,
                accuracy,
                speed: speed ?? null,
                batteryPercentage: batteryPercentage ?? null,
                chargingStatus: chargingStatus ?? null,
                gpsEnabled,
                internetAvailable,
                timestamp: new Date(timestamp),
              },
            });

            broadcastToAdmins({
              type: 'location_update',
              payload: {
                userId,
                name,
                latitude,
                longitude,
                accuracy,
                speed,
                batteryPercentage,
                chargingStatus,
                gpsEnabled,
                internetAvailable,
                timestamp,
              },
            });
          }
        } catch (err) {
          console.error('Error handling WebSocket message:', err);
        }
      });

      ws.on('close', async () => {
        connections.delete(userId);
        console.log(`WebSocket disconnected: User ${name}`);

        await prisma.user.update({
          where: { id: userId },
          data: { onlineStatus: false, lastSeen: new Date() },
        });

        broadcastToAdmins({
          type: 'presence_update',
          payload: { userId, online: false, lastSeen: new Date().toISOString() },
        });
      });
    } catch (err) {
      console.error('WebSocket connection setup failed:', err);
      ws.close(5000, 'Internal Server Error');
    }
  });
};

export const broadcastToAdmins = (message: any) => {
  const json = JSON.stringify(message);
  for (const conn of connections.values()) {
    if (conn.role === 'admin' && conn.ws.readyState === WebSocket.OPEN) {
      conn.ws.send(json);
    }
  }
};
