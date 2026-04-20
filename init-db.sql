-- Force the exact column order required by the Feb 2026 binary
DROP TABLE IF EXISTS users CASCADE;
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    notifications TEXT[] DEFAULT '{}',
    subscriptions TEXT[] DEFAULT '{}',
    preferences JSONB DEFAULT '{}',
    username TEXT UNIQUE,
    password TEXT,
    email TEXT DEFAULT '',
    created TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Ensure auxiliary tables exist for the 'Popular' and 'Channel' feeds
CREATE TABLE IF NOT EXISTS channels (id TEXT PRIMARY KEY, name TEXT, author TEXT, updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS session_ids (id TEXT PRIMARY KEY, user_id TEXT REFERENCES users(id) ON DELETE CASCADE, email TEXT DEFAULT '', created TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP);
