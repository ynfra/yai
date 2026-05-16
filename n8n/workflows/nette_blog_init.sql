-- Nette Blog RSS monitor — database setup
-- Run once against the nette_blog database.
--
-- One-time DB + user bootstrap (run as yai superuser):
--   psql -h 127.0.0.1 -p 25432 -U yai -d yai \
--     -c "CREATE DATABASE nette_blog; GRANT ALL ON DATABASE nette_blog TO yai;"
--
-- Then apply this file:
--   psql -h 127.0.0.1 -p 25432 -U yai -d nette_blog -f nette_blog_init.sql

CREATE TABLE IF NOT EXISTS rss_articles (
    id             SERIAL       PRIMARY KEY,
    guid           TEXT         UNIQUE NOT NULL,   -- MD5('nette:<url>')
    title          TEXT         NOT NULL,
    link           TEXT         NOT NULL,
    published_at   TIMESTAMPTZ,
    content        TEXT,                           -- extracted full-article plain text
    summary        TEXT,                           -- LLM-generated summary
    state          TEXT         NOT NULL DEFAULT 'pending',  -- pending | summarized | notified
    slack_notified BOOLEAN      DEFAULT FALSE,     -- legacy, kept for reference
    created_at     TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rss_articles_guid         ON rss_articles (guid);
CREATE INDEX IF NOT EXISTS idx_rss_articles_published_at ON rss_articles (published_at DESC);
CREATE INDEX IF NOT EXISTS idx_rss_articles_state        ON rss_articles (state);

-- State machine:  pending → summarized → notified
--   pending    : article downloaded, content extracted, waiting for AI summarisation
--   summarized : summary written, waiting for Slack notification
--   notified   : Slack message sent

-- ── Migration (apply to existing installs) ───────────────────────────────────
-- ALTER TABLE rss_articles ADD COLUMN IF NOT EXISTS state text NOT NULL DEFAULT 'pending';
-- UPDATE rss_articles SET state = 'notified'   WHERE slack_notified = true;
-- UPDATE rss_articles SET state = 'summarized' WHERE slack_notified = false AND summary IS NOT NULL AND summary <> '';
-- CREATE INDEX IF NOT EXISTS idx_rss_articles_state ON rss_articles (state);
