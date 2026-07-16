import { pool, initDb } from './index';

async function run() {
  console.log('Initializing database schema...');
  await initDb();
  console.log('Running database alterations...');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS online_status BOOLEAN NOT NULL DEFAULT FALSE;');
  await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE;');
  await pool.query('ALTER TABLE locations ADD COLUMN IF NOT EXISTS provider VARCHAR(50);');
  await pool.query('ALTER TABLE locations ADD COLUMN IF NOT EXISTS device_model VARCHAR(100);');
  console.log('Database alterations completed successfully.');
  process.exit(0);
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
