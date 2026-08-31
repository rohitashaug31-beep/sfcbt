import json
import streamlit as st
from snowflake.snowpark.context import get_active_session

# ---------- Config ----------
DB, SCHEMA, SERVICE = "RAG_DB", "CHATBOT", "POLICY_SEARCH_SVC"
RETURN_COLUMNS = ["chunk", "relative_path", "page_number"]

# Friendly name -> valid Cortex model id
MODELS = {
    "Llama 3.1 70B": "llama3.1-70b",
    "Llama 3.1 8B": "llama3.1-8b",
    "Claude Sonnet 4.6": "claude-sonnet-4-6",
}

SAMPLE_QUESTIONS = [
    "Can you summarise this document?",
    "Give me the top 5 points from this policy.",
    "What surgeries are covered?",
    "What is the waiting period?",
    "What are the key exclusions?",
]

GREETING = ("Hello! I'm the **Surgicare Policy Assistant**. I answer questions about "
            "the HDFC Surgicare Plan document only. Ask me to summarise it, list key "
            "points, or explain any term - answers stay within your chosen word limit, "
            "with sources.")

session = get_active_session()


def sql_str(s):
    """Escape a string for safe inlining into a SQL literal."""
    return s.replace("'", "''")


def retrieve(question, k):
    """Semantic retrieval via the Cortex Search service (hybrid search + reranking)."""
    payload = json.dumps({"query": question, "columns": RETURN_COLUMNS, "limit": k})
    sql = ("SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW("
           f"'{DB}.{SCHEMA}.{SERVICE}', '{sql_str(payload)}') AS r")
    raw = session.sql(sql).collect()[0][0]
    return json.loads(raw).get("results", [])


def generate(question, results, model_id, word_limit):
    context = "\n\n---\n\n".join(r.get("chunk", "") for r in results)
    prompt = (
        "You are the HDFC Surgicare Plan Assistant. You answer ONLY questions about "
        "the HDFC Surgicare insurance policy document, using ONLY the context below.\n"
        "Rules:\n"
        "1. If the question is not about this Surgicare policy document, politely reply "
        "that you can only answer questions about the Surgicare policy document.\n"
        "2. Base your answer strictly on the context. If the answer is not in the "
        "context, say you could not find it in the policy document.\n"
        f"3. Keep your answer under {word_limit} words. Be clear and specific.\n\n"
        f"Context:\n{context}\n\n"
        f"Question: {question}\n\nAnswer:"
    )
    sql = f"SELECT SNOWFLAKE.CORTEX.COMPLETE('{model_id}', '{sql_str(prompt)}') AS answer"
    return session.sql(sql).collect()[0][0]


# ---------- Header ----------
st.title("HDFC Surgicare Policy Assistant")
st.caption("Ask about the HDFC Surgicare Plan - grounded answers, with sources.")

if "messages" not in st.session_state:
    st.session_state.messages = [{"role": "assistant", "content": GREETING}]

# ---------- Sidebar ----------
pending = None
with st.sidebar:
    st.markdown("### Model")
    model_label = st.selectbox("Choose a model", list(MODELS.keys()))
    model_id = MODELS[model_label]

    word_limit = st.slider("Answer length (words)", 50, 2000, 150, step=50,
                           help="Max words the answer can use. Default 150. "
                                "For long answers, also raise Context chunks.")

    num_chunks = st.slider("Context chunks", 3, 15, 8,
                           help="More chunks = better for whole-document summaries.")

    st.divider()
    st.markdown("### Try asking")
    for i, q in enumerate(SAMPLE_QUESTIONS):
        if st.button(q, key=f"sq_{i}", use_container_width=True):
            pending = q

    st.divider()
    if st.button("Clear chat", use_container_width=True):
        st.session_state.messages = [{"role": "assistant", "content": GREETING}]
        st.rerun()

# ---------- History ----------
for m in st.session_state.messages:
    with st.chat_message(m["role"]):
        st.markdown(m["content"])

# ---------- Input ----------
typed = st.chat_input("Ask about the Surgicare policy...")
if typed:
    pending = typed

# ---------- Process ----------
if pending:
    st.session_state.messages.append({"role": "user", "content": pending})
    with st.chat_message("user"):
        st.markdown(pending)

    with st.chat_message("assistant"):
        with st.spinner("Searching the policy..."):
            results = retrieve(pending, num_chunks)
            answer = generate(pending, results, model_id, word_limit)
        st.markdown(answer)

        seen, sources = set(), []
        for r in results:
            path, page = r.get("relative_path"), r.get("page_number")
            key = (path, page)
            if key not in seen:
                seen.add(key)
                sources.append(f"- **{path}** - page {page}")
        if sources:
            with st.expander("Sources"):
                st.markdown("\n".join(sources))

    st.session_state.messages.append({"role": "assistant", "content": answer})

# ---------- Footer disclaimer ----------
st.divider()
st.caption(
    "Disclaimer: Responses are generated by AI and may be incomplete or inaccurate. "
    "This assistant is not a substitute for the official policy document or "
    "professional advice - please verify any answer against the actual HDFC "
    "Surgicare policy before relying on it."
)