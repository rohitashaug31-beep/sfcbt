USE ROLE ACCOUNTADMIN;

-- 1. Your OWN compute (not the default COMPUTE_WH)
CREATE OR REPLACE WAREHOUSE chatbot_wh
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

  -- 2. Your OWN database
CREATE DATABASE IF NOT EXISTS rag_db;
-- 3. Your OWN schema (named 'chatbot', NOT public)
CREATE SCHEMA IF NOT EXISTS rag_db.chatbot;


-- 4. Point this session at all three
USE WAREHOUSE chatbot_wh;
USE DATABASE rag_db;
USE SCHEMA rag_db.chatbot;