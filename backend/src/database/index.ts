import { Pool } from 'pg';
import { config } from '../config';
import fs from 'fs';
import path from 'path';
import { Logger } from '../shared/logger';
import { prisma } from './prisma';

export const pool = new Pool({
  connectionString: config.databaseUrl,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

export const query = (text: string, params?: any[]) => {
  return pool.query(text, params);
};

export const initDb = async () => {
  try {
    const schemaPath = path.join(__dirname, '../../schema.sql');
    const schemaSql = fs.readFileSync(schemaPath, 'utf8');
    await pool.query(schemaSql);
    Logger.info('Database initialized successfully.');
    
    const adminCount = await prisma.user.count({
      where: { role: 'admin' },
    });
    
    if (adminCount === 0) {
      const bcrypt = require('bcryptjs');
      const hash = await bcrypt.hash('admin123', 10);
      await prisma.user.create({
        data: {
          email: 'admin@tracker.com',
          passwordHash: hash,
          role: 'admin',
          name: 'Family Admin',
          phone: '1234567890',
        },
      });
      Logger.info('Seeded default admin user: admin@tracker.com / admin123');
    }
  } catch (error) {
    Logger.error('Failed to initialize database:', error);
  }
};
