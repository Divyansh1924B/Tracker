import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { pool } from '../database';

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    role: 'admin' | 'member';
  };
}

export const authMiddleware = async (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No token provided', code: 'UNAUTHORIZED' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, config.jwtSecret) as { userId: string; sessionId: string };
    
    // Query database to check if the session is still active and valid
    const userRes = await pool.query(
      'SELECT id, email, role, current_session_id FROM users WHERE id = $1',
      [decoded.userId]
    );

    if (userRes.rows.length === 0) {
      return res.status(401).json({ error: 'User not found', code: 'UNAUTHORIZED' });
    }

    const user = userRes.rows[0];

    // Enforce "One Account = One Active Device" policy
    if (user.current_session_id !== decoded.sessionId) {
      return res.status(401).json({ 
        error: 'Session invalidated due to login on another device', 
        code: 'SESSION_INVALIDATED' 
      });
    }

    (req as AuthenticatedRequest).user = {
      id: user.id,
      email: user.email,
      role: user.role,
    };

    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid or expired token', code: 'UNAUTHORIZED' });
  }
};

