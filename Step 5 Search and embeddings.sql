-- 4. Point this session at all three
USE WAREHOUSE chatbot_wh;
USE DATABASE rag_db;
USE SCHEMA rag_db.chatbot;

USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

CREATE OR REPLACE CORTEX SEARCH SERVICE policy_search_svc
  ON chunk
  ATTRIBUTES relative_path, page_number
  WAREHOUSE = chatbot_wh
  TARGET_LAG = '1 day'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
  AS (
    SELECT chunk, relative_path, page_number
    FROM docs_chunks
  );


  SHOW CORTEX SEARCH SERVICES;

  SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'RAG_DB.CHATBOT.POLICY_SEARCH_SVC',
    '{
       "query": "What is the waiting period for pre-existing conditions?",
       "columns": ["chunk", "relative_path", "page_number"],
       "limit": 3
     }'
  )
) AS results;



CREATE OR REPLACE TABLE docs_embeddings AS
SELECT
  relative_path, page_number, chunk,
  SNOWFLAKE.CORTEX.EMBED_TEXT_1024('snowflake-arctic-embed-l-v2.0', chunk) AS embedding
FROM docs_chunks;


select * from RAG_DB.CHATBOT.DOCS_EMBEDDINGS;

SELECT
  ARRAY_SIZE(embedding::ARRAY) AS dimensions
FROM docs_embeddings
LIMIT 1;