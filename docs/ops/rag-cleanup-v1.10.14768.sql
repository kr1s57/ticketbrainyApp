-- ============================================================================
-- TicketBrainy v1.10.14768 — RAG Knowledge Builder cleanup
-- ============================================================================
-- Purpose: one-shot purge of AiKnowledgeChunk rows accumulated by the
-- pre-v1.10.14768 RAG crawler. Aligns existing prod data with the new
-- invariant enforced by topic-crawler.ts after this release:
--   * at most 5 URLs per topic
--   * at most 1 chunk per URL (the earliest = article intro)
--
-- After v1.10.14768 is deployed, this script is no longer strictly
-- needed: every successful crawl re-enforces the invariant via
-- pruneTopic(). But running it once on upgrade gives an immediate
-- clean slate without waiting for new tickets to trigger crawls.
--
-- ----------------------------------------------------------------------------
-- How to run on a production stack
-- ----------------------------------------------------------------------------
--
-- 1. Copy this file into the running db container:
--      docker cp docs/ops/rag-cleanup-v1.10.14768.sql \
--        $(docker compose ps -q db):/tmp/rag-cleanup.sql
--
-- 2. Execute it:
--      docker compose exec db \
--        psql -U "$DB_USER" -d "$DB_NAME" -f /tmp/rag-cleanup.sql
--
-- 3. (Optional) verify the result:
--      docker compose exec db psql -U "$DB_USER" -d "$DB_NAME" -c \
--        'SELECT topic, COUNT(*) AS chunks, COUNT(DISTINCT url) AS urls
--           FROM "AiKnowledgeChunk" GROUP BY topic ORDER BY topic;'
--    Expected: each topic shows at most 5 chunks and 5 distinct URLs.
--
-- Safe to re-run. Idempotent. Wrapped in a single transaction so a
-- failure rolls everything back. No service downtime — the ai-service
-- only reads from this table during Deep Analysis, never writes
-- without going through pruneTopic().
-- ============================================================================

BEGIN;

WITH first_chunk_per_url AS (
  -- For each (topic, url), keep only the earliest chunk = article intro
  SELECT DISTINCT ON (topic, url) id, topic, url, "fetchedAt"
  FROM "AiKnowledgeChunk"
  ORDER BY topic, url, "fetchedAt" ASC, id ASC
),
ranked_urls AS (
  -- Within each topic, rank surviving chunks by URL recency
  SELECT id, topic, url, "fetchedAt",
    ROW_NUMBER() OVER (PARTITION BY topic ORDER BY "fetchedAt" DESC, id DESC) AS rn
  FROM first_chunk_per_url
),
to_keep AS (
  -- Final keep-set: top-5 URLs per topic, 1 chunk each
  SELECT id FROM ranked_urls WHERE rn <= 5
)
DELETE FROM "AiKnowledgeChunk"
WHERE id NOT IN (SELECT id FROM to_keep);

COMMIT;
