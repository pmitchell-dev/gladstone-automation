-- Force the exact column order required by Invidious v2.20260207.0 (Blind Insert Match)
-- Verified against official config/sql/ definitions for Feb 2026 build

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
    feed_needs_update BOOLEAN DEFAULT FALSE,
    CONSTRAINT users_email_key UNIQUE (email)
);

DROP TABLE IF EXISTS session_ids CASCADE;
CREATE TABLE session_ids (
    id TEXT NOT NULL,
    email TEXT,
    issued TIMESTAMP WITH TIME ZONE,
    CONSTRAINT session_ids_pkey PRIMARY KEY (id)
);

DROP TABLE IF EXISTS channels CASCADE;
CREATE TABLE channels (
    id TEXT NOT NULL,
    author TEXT,
    updated TIMESTAMP WITH TIME ZONE,
    deleted BOOLEAN DEFAULT FALSE,
    subscribed TIMESTAMP WITH TIME ZONE,
    CONSTRAINT channels_id_key UNIQUE (id)
);

-- Auxiliary table for videos (Unlogged for performance as per v2.20260207.0)
DROP TABLE IF EXISTS videos CASCADE;
CREATE UNLOGGED TABLE videos (
    id TEXT NOT NULL,
    info TEXT,
    updated TIMESTAMP WITH TIME ZONE,
    CONSTRAINT videos_pkey PRIMARY KEY (id)
);
