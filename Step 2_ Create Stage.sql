-- 4. Point this session at all three
USE WAREHOUSE chatbot_wh;
USE DATABASE rag_db;
USE SCHEMA rag_db.chatbot;


-- Create the stage to store the docs.
CREATE OR REPLACE STAGE docs_stage
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

SELECT * FROM DIRECTORY('@docs_stage');

LIST @docs_stage;
SELECT CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_WAREHOUSE();