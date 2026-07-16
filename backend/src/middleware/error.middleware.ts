import { Request, Response, NextFunction } from 'express';
import { Logger } from '../shared/logger';

export const errorMiddleware = (err: any, req: Request, res: Response, _next: NextFunction) => {
  Logger.error(`${req.method} ${req.path} failed:`, err);
  
  const status = err.status || 500;
  const message = process.env.NODE_ENV === 'production' && status === 500
    ? 'Internal Server Error'
    : err.message || 'Internal Server Error';

  res.status(status).json({ error: message });
};
