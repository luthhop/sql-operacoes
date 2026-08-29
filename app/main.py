import sqlite3
from pathlib import Path

import pandas as pd
import plotly.graph_objects as go
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

# --- Sazonalidade ---

st.header("Sazonalidade")

NOMES_MES = {
    1: "Jan", 2: "Fev", 3: "Mar", 4: "Abr", 5: "Mai", 6: "Jun",
    7: "Jul", 8: "Ago", 9: "Set", 10: "Out", 11: "Nov", 12: "Dez",
}

# Pontualidade por mes do ano (agregado)
df_mes = run_query(
    f"""
    SELECT
        CAST(SUBSTR(ano_mes_referencia, 6, 2) AS INTEGER) AS mes,
        ROUND(
            SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
            * 100.0
            / SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END),
            2
        ) AS taxa_pontualidade_pct
    FROM vw_voos_analitico
    WHERE {clausula_ano}
    GROUP BY mes
    ORDER BY mes
    """,
    filtro_anos,
)
df_mes["nome_mes"] = df_mes["mes"].map(NOMES_MES)
df_mes["destaque"] = df_mes["mes"] == 12

col_saz1, col_saz2 = st.columns(2)

with col_saz1:
    st.subheader("Pontualidade por mes")
    cores = ["#e74c3c" if d else "#3498db" for d in df_mes["destaque"]]
    fig_mes = go.Figure()
    fig_mes.add_trace(go.Scatter(
        x=df_mes["nome_mes"],
        y=df_mes["taxa_pontualidade_pct"],
        mode="lines+markers",
        marker=dict(color=cores, size=10),
        line=dict(color="#3498db", width=2),
        hovertemplate="%{x}: %{y:.1f}%<extra></extra>",
    ))
    fig_mes.add_annotation(
        x="Dez",
        y=df_mes.loc[df_mes["mes"] == 12, "taxa_pontualidade_pct"].iloc[0],
        text="Pior mes",
        showarrow=True,
        arrowhead=2,
        ax=0,
        ay=-30,
        font=dict(color="#e74c3c", size=12),
    )
    fig_mes.update_layout(
        yaxis_title="Pontualidade (%)",
        xaxis_title=None,
        margin=dict(l=40, r=20, t=20, b=40),
        height=350,
        showlegend=False,
    )
    st.plotly_chart(fig_mes, use_container_width=True)

# Pontualidade por dia da semana
NOMES_DIA = {
    0: "Dom", 1: "Seg", 2: "Ter", 3: "Qua", 4: "Qui", 5: "Sex", 6: "Sab",
}
ORDEM_DIA = [1, 2, 3, 4, 5, 6, 0]

df_dia = run_query(
    f"""
    SELECT
        CAST(strftime('%w', "Partida Prevista") AS INTEGER) AS dia_semana_num,
        ROUND(
            SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
            * 100.0
            / SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END),
            2
        ) AS taxa_pontualidade_pct
    FROM vw_voos_analitico
    WHERE "Partida Prevista" IS NOT NULL
      AND {clausula_ano}
    GROUP BY dia_semana_num
    ORDER BY dia_semana_num
    """,
    filtro_anos,
)
df_dia["nome_dia"] = df_dia["dia_semana_num"].map(NOMES_DIA)
df_dia["ordem"] = df_dia["dia_semana_num"].map(dict(zip(ORDEM_DIA, range(7))))
df_dia = df_dia.sort_values("ordem")

with col_saz2:
    st.subheader("Pontualidade por dia da semana")
    cores_dia = ["#e74c3c" if d == 5 else "#3498db" for d in df_dia["dia_semana_num"]]
    fig_dia = go.Figure()
    fig_dia.add_trace(go.Bar(
        x=df_dia["nome_dia"],
        y=df_dia["taxa_pontualidade_pct"],
        marker_color=cores_dia,
        hovertemplate="%{x}: %{y:.1f}%<extra></extra>",
    ))
    fig_dia.update_layout(
        yaxis_title="Pontualidade (%)",
        xaxis_title=None,
        margin=dict(l=40, r=20, t=20, b=40),
        height=350,
    )
    st.plotly_chart(fig_dia, use_container_width=True)

st.caption(
    "Dezembro e consistentemente o pior mes do periodo "
    "(atraso medio de ate 13,4 min em dez/2025), e sexta-feira e o pior dia da "
    "semana. Fins de semana tem operacao mais estavel."
)

# --- Cruzamento aeroporto x mes ---

st.header("Onde a Sazonalidade Mais Afeta a Operacao")
st.markdown("*Dados consolidados de 2024-2025*", unsafe_allow_html=True)

NOMES_AEROPORTO = {
    "SBSP": "SBSP (Congonhas)",
    "SBGR": "SBGR (Guarulhos)",
    "SBKP": "SBKP (Viracopos)",
    "SBGL": "SBGL (Galeao)",
    "SBBR": "SBBR (Brasilia)",
    "SBCF": "SBCF (Confins)",
    "SBSV": "SBSV (Salvador)",
    "SBRF": "SBRF (Recife)",
    "SBFZ": "SBFZ (Fortaleza)",
    "SBCT": "SBCT (Curitiba)",
    "SBRJ": "SBRJ (S. Dumont)",
    "SBFL": "SBFL (Florianopolis)",
    "SBBE": "SBBE (Belem)",
    "SBEG": "SBEG (Manaus)",
}

df_heatmap = run_query("""
    WITH top15 AS (
        SELECT "ICAO Aeródromo Origem" AS aeroporto
        FROM vw_voos_operacionais
        WHERE "ICAO Aeródromo Origem" != 'SBPA'
        GROUP BY "ICAO Aeródromo Origem"
        HAVING COUNT(*) >= 5000
        ORDER BY COUNT(*) DESC
        LIMIT 14
    ),
    por_mes AS (
        SELECT
            v."ICAO Aeródromo Origem" AS aeroporto,
            CAST(SUBSTR(v.ano_mes_referencia, 6, 2) AS INTEGER) AS mes,
            ROUND(
                SUM(CASE WHEN v.categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
                * 100.0
                / NULLIF(SUM(CASE WHEN v.categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END), 0),
                2
            ) AS pontualidade
        FROM vw_voos_operacionais v
        INNER JOIN top15 t ON v."ICAO Aeródromo Origem" = t.aeroporto
        GROUP BY v."ICAO Aeródromo Origem", CAST(SUBSTR(v.ano_mes_referencia, 6, 2) AS INTEGER)
    ),
    variacao AS (
        SELECT
            aeroporto,
            ROUND(
                MAX(CASE WHEN mes = 12 THEN pontualidade END)
                - AVG(CASE WHEN mes != 12 THEN pontualidade END),
                2
            ) AS variacao_dez_pp
        FROM por_mes
        GROUP BY aeroporto
    )
    SELECT pm.aeroporto, pm.mes, pm.pontualidade, v.variacao_dez_pp
    FROM por_mes pm
    INNER JOIN variacao v ON pm.aeroporto = v.aeroporto
    ORDER BY v.variacao_dez_pp ASC, pm.mes
""")

df_heatmap["nome_aeroporto"] = df_heatmap["aeroporto"].map(
    lambda x: NOMES_AEROPORTO.get(x, x)
)
df_heatmap["nome_mes"] = df_heatmap["mes"].map(NOMES_MES)

ordem_aeroportos = (
    df_heatmap[["nome_aeroporto", "variacao_dez_pp"]]
    .drop_duplicates()
    .sort_values("variacao_dez_pp")["nome_aeroporto"]
    .tolist()
)

pivot = df_heatmap.pivot(index="nome_aeroporto", columns="nome_mes", values="pontualidade")
meses_ordenados = [NOMES_MES[i] for i in range(1, 13)]
pivot = pivot[meses_ordenados]
pivot = pivot.loc[ordem_aeroportos]

fig_heat = go.Figure(data=go.Heatmap(
    z=pivot.values,
    x=pivot.columns.tolist(),
    y=pivot.index.tolist(),
    colorscale=[
        [0.0, "#b71c1c"],
        [0.3, "#e57373"],
        [0.5, "#fff176"],
        [0.7, "#81c784"],
        [1.0, "#1b5e20"],
    ],
    zmin=76,
    zmax=97,
    hovertemplate="%{y}<br>%{x}: %{z:.1f}%<extra></extra>",
    colorbar=dict(title="Pont. (%)"),
))
fig_heat.update_layout(
    yaxis=dict(autorange="reversed"),
    xaxis_title=None,
    yaxis_title=None,
    margin=dict(l=160, r=20, t=20, b=40),
    height=500,
)
st.plotly_chart(fig_heat, use_container_width=True)

st.caption(
    "O efeito sazonal de dezembro nao e uniforme: Congonhas (-12,6 p.p.), "
    "Viracopos e Guarulhos concentram a maior queda de pontualidade do pais "
    "nesse periodo — provavelmente pela combinacao de alta demanda de fim de "
    "ano com temporais de verao no Sudeste. Aeroportos do Norte/Nordeste "
    "(Manaus, Recife, Belem) sofrem proporcionalmente menos."
)
st.caption(
    "Nota: SBPA (Porto Alegre) foi excluido desta comparacao devido a "
    "interrupcao de operacao causada pelas enchentes do Rio Grande do Sul "
    "(mai-nov/2024), o que tornaria a comparacao sazonal mensal nao "
    "representativa para esse aeroporto no periodo."
)

# --- Rankings: Aeroportos e Companhias ---

st.header("Rankings: Aeroportos e Companhias")

tab_aero, tab_cia = st.tabs(["Aeroportos", "Companhias"])

with tab_aero:
    col_aero1, col_aero2 = st.columns(2)

    with col_aero1:
        st.subheader("Pior pontualidade (min. 5.000 voos)")
        df_aero_pont = run_query(
            f"""
            SELECT
                "ICAO Aeródromo Origem" AS aeroporto,
                COUNT(*) AS total_voos,
                ROUND(
                    SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
                    * 100.0
                    / NULLIF(SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END), 0),
                    2
                ) AS taxa_pontualidade_pct
            FROM vw_voos_operacionais
            WHERE {clausula_ano}
            GROUP BY "ICAO Aeródromo Origem"
            HAVING COUNT(*) >= 5000
            ORDER BY taxa_pontualidade_pct ASC
            LIMIT 10
            """,
            filtro_anos,
        )
        df_aero_pont = df_aero_pont.sort_values("taxa_pontualidade_pct", ascending=True)
        fig_aero = go.Figure()
        fig_aero.add_trace(go.Bar(
            y=df_aero_pont["aeroporto"],
            x=df_aero_pont["taxa_pontualidade_pct"],
            orientation="h",
            marker_color="#e74c3c",
            text=df_aero_pont["taxa_pontualidade_pct"].apply(lambda v: f"{v:.1f}%"),
            textposition="outside",
            hovertemplate="%{y}: %{x:.1f}%<extra></extra>",
        ))
        fig_aero.update_layout(
            xaxis_title="Pontualidade (%)",
            yaxis=dict(autorange="reversed"),
            margin=dict(l=60, r=60, t=20, b=40),
            height=400,
        )
        st.plotly_chart(fig_aero, use_container_width=True)

    with col_aero2:
        st.subheader("Maior cancelamento real (min. 5.000 voos)")
        df_aero_canc = run_query(
            f"""
            SELECT
                "ICAO Aeródromo Origem" AS aeroporto,
                COUNT(*) AS total_voos,
                SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END) AS cancelados,
                ROUND(
                    SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
                    * 100.0 / COUNT(*), 2
                ) AS taxa_cancelamento_pct
            FROM vw_voos_operacionais
            WHERE {clausula_ano}
            GROUP BY "ICAO Aeródromo Origem"
            HAVING COUNT(*) >= 5000
            ORDER BY taxa_cancelamento_pct DESC
            LIMIT 5
            """,
            filtro_anos,
        )
        df_aero_canc = df_aero_canc.sort_values("taxa_cancelamento_pct", ascending=True)
        cores_canc = [
            "#b71c1c" if a == "SBJR" else "#e74c3c"
            for a in df_aero_canc["aeroporto"]
        ]
        fig_canc = go.Figure()
        fig_canc.add_trace(go.Bar(
            y=df_aero_canc["aeroporto"],
            x=df_aero_canc["taxa_cancelamento_pct"],
            orientation="h",
            marker_color=cores_canc,
            text=df_aero_canc["taxa_cancelamento_pct"].apply(lambda v: f"{v:.1f}%"),
            textposition="outside",
            hovertemplate="%{y}: %{x:.1f}%<br>%{customdata} cancelados<extra></extra>",
            customdata=df_aero_canc["cancelados"],
        ))
        fig_canc.update_layout(
            xaxis_title="Cancelamento (%)",
            yaxis=dict(autorange="reversed"),
            margin=dict(l=60, r=60, t=20, b=40),
            height=400,
        )
        st.plotly_chart(fig_canc, use_container_width=True)

with tab_cia:
    st.subheader("Pontualidade por companhia (min. 5.000 voos, completude >= 50%)")
    NACIONAIS = {"GLO", "TAM", "AZU"}
    df_cia = run_query(
        f"""
        SELECT
            "ICAO Empresa Aérea" AS empresa,
            COUNT(*) AS total_voos,
            ROUND(
                SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
                * 100.0
                / NULLIF(SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END), 0),
                2
            ) AS taxa_pontualidade_pct,
            ROUND(AVG(CASE WHEN atraso_partida_min IS NOT NULL THEN atraso_partida_min END), 1) AS atraso_medio_min
        FROM vw_voos_operacionais
        WHERE {clausula_ano}
        GROUP BY "ICAO Empresa Aérea"
        HAVING COUNT(*) >= 5000
           AND SUM(CASE WHEN atraso_partida_min IS NOT NULL THEN 1 ELSE 0 END) * 1.0 / COUNT(*) >= 0.5
        ORDER BY taxa_pontualidade_pct DESC
        """,
        filtro_anos,
    )
    df_cia = df_cia.sort_values("taxa_pontualidade_pct", ascending=True)
    cores_cia = [
        "#2e7d32" if e in NACIONAIS else "#3498db"
        for e in df_cia["empresa"]
    ]
    fig_cia = go.Figure()
    fig_cia.add_trace(go.Bar(
        y=df_cia["empresa"],
        x=df_cia["taxa_pontualidade_pct"],
        orientation="h",
        marker_color=cores_cia,
        text=df_cia["taxa_pontualidade_pct"].apply(lambda v: f"{v:.1f}%"),
        textposition="outside",
        hovertemplate="%{y}: %{x:.1f}% (%{customdata} voos)<extra></extra>",
        customdata=df_cia["total_voos"],
    ))
    fig_cia.update_layout(
        xaxis_title="Pontualidade (%)",
        yaxis=dict(autorange="reversed"),
        margin=dict(l=60, r=60, t=20, b=40),
        height=max(350, len(df_cia) * 30),
    )
    st.plotly_chart(fig_cia, use_container_width=True)
    st.caption("Barras verdes: grandes nacionais (GLO, TAM, AZU)")

with st.expander("Sobre a qualidade dos dados"):
    st.markdown(
        "Para garantir rankings justos, foram excluidos desta analise: "
        "**(1)** registros de voos autorizados mas nunca operados "
        "(codeshares/parcerias nao efetivadas), que inflavam artificialmente "
        "o cancelamento de certos aeroportos e empresas, e "
        "**(2)** companhias com mais de 50% de dados incompletos, geralmente "
        "operadoras de carga com padrao de escala incompativel com a metrica, "
        "ou com defasagem de reporte da ANAC a partir de abril/2025."
    )
