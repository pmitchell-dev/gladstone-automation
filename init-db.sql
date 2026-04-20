-- Force the exact column order required by Invidious v2.20260207.0 (Blind Insert Match)
DROP TABLE IF EXISTS users CASCADE;
CREATE TABLE users (
    updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    notifications TEXT[] DEFAULT '{}',
    subscriptions TEXT[] DEFAULT '{}',
    email TEXT NOT NULL UNIQUE,
    preferences TEXT DEFAULT '{}',
    password TEXT,
    token TEXT,
    watched TEXT[] DEFAULT '{}',
    feed_needs_update BOOLEAN DEFAULT FALSE
);

-- Ensure auxiliary tables exist for the 'Popular' and 'Channel' feeds
CREATE TABLE IF NOT EXISTS channels (id TEXT PRIMARY KEY, name TEXT, author TEXT, updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS session_ids (id TEXT PRIMARY KEY, user_id TEXT REFERENCES users(id) ON DELETE CASCADE, email TEXT DEFAULT '', created TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP);
