-- Primary DB: links table
-- See Decisions Log #1, #2, #13, #14, #15 for rationale behind each choice below.

CREATE TABLE links (
    id            BIGSERIAL PRIMARY KEY,                       -- Internal surrogate key. Auto-increment is fine here:
                                                                 -- never exposed externally, so no enumeration risk (Decision #13).
    short_code    VARCHAR(32) NOT NULL UNIQUE,                  -- Holds auto-generated random codes AND custom aliases +
                                                                 -- collision suffix, e.g. "custom-promo-x7f2" (Decision #14).
                                                                 -- UNIQUE enforces Decision #13's core guarantee.
    long_url      TEXT NOT NULL,
    user_id       BIGINT NOT NULL,                              -- Logical FK to Auth DB's users table. NOT a real FK
                                                                 -- constraint -- Auth DB is a separate database (HLD),
                                                                 -- so referential integrity is enforced in application
                                                                 -- code (Shortening Service validates user_id from token).
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at    TIMESTAMP WITH TIME ZONE NULL,                 -- NULL = never expires.

    UNIQUE (user_id, long_url)                                    -- Enforces per-user idempotency (Decision #1):
                                                                 -- same user + same long_url always maps to the
                                                                 -- same short_code.
);

-- Note: requested_alias is intentionally NOT a column (Decision #15) -- it's computed
-- in memory at creation time and returned once in the API response, never persisted.

-- Note: on MySQL/InnoDB, UNIQUE(user_id, long_url) would require a defined prefix
-- length on the long_url portion of the index, since TEXT columns aren't indexable
-- at full length by default. Not a blocker for Postgres; revisit if the engine changes.