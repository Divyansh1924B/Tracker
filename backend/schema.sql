-- User Roles
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('admin', 'member');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Users Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'member',
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    device_name VARCHAR(100),
    photo_url TEXT,
    current_session_id UUID,
    deleted_at TIMESTAMP WITH TIME ZONE,
    online_status BOOLEAN NOT NULL DEFAULT FALSE,
    last_seen TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index on email
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Locations Table
CREATE TABLE IF NOT EXISTS locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy REAL NOT NULL,
    speed REAL,
    battery_percentage INT,
    charging_status BOOLEAN,
    gps_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    internet_available BOOLEAN NOT NULL DEFAULT TRUE,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    provider VARCHAR(50),
    device_model VARCHAR(100)
);

-- Index on user_id and timestamp for rapid range-based route lookups
CREATE INDEX IF NOT EXISTS idx_locations_user_time ON locations(user_id, timestamp DESC);
