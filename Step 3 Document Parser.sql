-- 4. Point this session at all three
USE WAREHOUSE chatbot_wh;
USE DATABASE rag_db;
USE SCHEMA rag_db.chatbot;
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'llama3.1-8b',
  'Reply with one short friendly sentence to confirm you are working.'
);



CREATE OR REPLACE TABLE docs_parsed AS
SELECT
  relative_path,
  AI_PARSE_DOCUMENT(
    TO_FILE('@docs_stage', relative_path),
    {'mode': 'LAYOUT', 'page_split': TRUE}
  ) AS parsed
FROM DIRECTORY('@docs_stage');



SELECT
  d.relative_path,
  d.parsed:metadata:pageCount::INT AS total_pages,
  LEFT(f.value:content::STRING, 400) AS sample_text
FROM docs_parsed d,
     LATERAL FLATTEN(input => d.parsed:pages) f
WHERE f.index = 0;