import sqlite3
from pathlib import Path

import pandas as pd
import streamlit as st

DB_PATH = Path(__file__).resolve().parent.parent / "data" / "processed" / "vra.db"

st.set_page_config(
    page_title="SQL Operacoes — Analise de Voos ANAC",
    page_icon="✈️",
    layout="wide",
)


@st.cache_resource
def get_connection():
    return sqlite3.connect(str(DB_PATH), check_same_thread=False)


def run_query(query: str, params: tuple = ()) -> pd.DataFrame:
    return pd.read_sql_query(query, get_connection(), params=params)


# --- Cabecalho ---

st.title("✈️ SQL Operacoes")
st.markdown(
    "Analise de pontualidade e cancelamento de voos no Brasil, "
    "com dados publicos da ANAC — 2024/2025 · "
    "[Repositorio GitHub](https://github.com/luthhop/sql-operacoes)"
)

# --- Sidebar: filtros ---

st.sidebar.header("Filtros")
opcao_ano = st.sidebar.radio("Periodo", ["2024 e 2025", "2024", "2025"])

if opcao_ano == "2024":
    filtro_anos = ("2024",)
    clausula_ano = "SUBSTR(ano_mes_referencia, 1, 4) = ?"
elif opcao_ano == "2025":
    filtro_anos = ("2025",)
    clausula_ano = "SUBSTR(ano_mes_referencia, 1, 4) = ?"
else:
    filtro_anos = ("2024", "2025")
    clausula_ano = "SUBSTR(ano_mes_referencia, 1, 4) IN (?, ?)"

# --- Visao Geral ---

st.header("Visao Geral")

query_metricas = f"""
SELECT
    COUNT(*) AS total_voos,
    ROUND(
        SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
        * 100.0
        / NULLIF(SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END), 0),
        2
    ) AS taxa_pontualidade_pct,
    ROUND(
        SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS taxa_cancelamento_pct,
    ROUND(AVG(CASE WHEN atraso_partida_min IS NOT NULL THEN atraso_partida_min END), 1) AS atraso_medio_min
FROM vw_voos_analitico
WHERE {clausula_ano}
"""

df = run_query(query_metricas, filtro_anos)
row = df.iloc[0]

c1, c2, c3, c4 = st.columns(4)
c1.metric("Total de voos", f"{int(row['total_voos']):,}".replace(",", "."))
c2.metric("Pontualidade", f"{row['taxa_pontualidade_pct']:.1f}%")
c3.metric("Cancelamento", f"{row['taxa_cancelamento_pct']:.1f}%")
c4.metric("Atraso medio", f"{row['atraso_medio_min']:.1f} min")
