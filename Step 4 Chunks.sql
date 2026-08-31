-- 4. Point this session at all three
USE WAREHOUSE chatbot_wh;
USE DATABASE rag_db;
USE SCHEMA rag_db.chatbot;
CREATE OR REPLACE TABLE docs_chunks AS
WITH pages AS (
  SELECT
    d.relative_path,
    p.value:index::INT     AS page_number,
    p.value:content::STRING AS page_text
  FROM docs_parsed d,
       LATERAL FLATTEN(input => d.parsed:pages) p
),
chunked AS (
  SELECT
    relative_path,
    page_number,
    SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(
      page_text,
      'markdown',   -- respects headings/tables when splitting
      500,         -- chunk size in characters
      100           -- overlap in characters
    ) AS chunks
  FROM pages
)
SELECT
  relative_path,
  page_number,
  c.index          AS chunk_number,
  c.value::STRING  AS chunk
FROM chunked,
     LATERAL FLATTEN(input => chunks) c;


     SELECT COUNT(*) AS total_chunks,
       COUNT(DISTINCT relative_path) AS docs
FROM docs_chunks;

SELECT relative_path, page_number, LEFT(chunk, 200) AS preview
FROM docs_chunks
LIMIT 100;