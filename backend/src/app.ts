import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import { config } from './config';
import { errorMiddleware } from './middleware/error.middleware';
import { authRouter } from './modules/auth/auth.controller';
import { membersRouter } from './modules/members/members.controller';
import { locationsRouter } from './modules/locations/locations.controller';
import { initWebSocketServer } from './websocket/tracker.ws';

const app = express();
const server = createServer(app);
const wss = new WebSocketServer({ noServer: true });

// Setup middleware
app.use(cors());
app.use(express.json());

// Routes Setup
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/api/auth', authRouter);
app.use('/api/members', membersRouter);
app.use('/api/locations', locationsRouter);

// Error handling middleware (should be registered last)
app.use(errorMiddleware);

// Handle upgrading connection to WebSockets
server.on('upgrade', (request, socket, head) => {
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit('connection', ws, request);
  });
});

// Initialize WebSocket logic
initWebSocketServer(wss);

import { initDb } from './database';

initDb().then(() => {
  server.listen(config.port, () => {
    console.log(`Server is running on port ${config.port}`);
  });
});
export { app, server };

