-- The gateway reads/writes the same `users` table the auth-gate creates.
-- These columns drive per-user model routing + spend accounting.
-- (Run against the SAME D1 database as the auth-gate.)
ALTER TABLE users ADD COLUMN model_pref     TEXT DEFAULT 'deepseek';  -- 'deepseek' | 'claude'
ALTER TABLE users ADD COLUMN model_unlocks  TEXT DEFAULT '[]';        -- JSON array of premium model ids
ALTER TABLE users ADD COLUMN deepseek_model TEXT;
ALTER TABLE users ADD COLUMN claude_model   TEXT;
ALTER TABLE users ADD COLUMN free_deepseek  INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN boost_day      TEXT;
ALTER TABLE users ADD COLUMN boost_used     INTEGER DEFAULT 0;

-- optional per-request usage log (if you want in-D1 accounting alongside AI Gateway logs)
CREATE TABLE IF NOT EXISTS usage_log (
  ts INTEGER, discord_id TEXT, provider TEXT, model TEXT,
  tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL
);
