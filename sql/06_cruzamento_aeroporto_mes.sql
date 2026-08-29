-- Cruzamento aeroporto × mês — VRA (ANAC)
-- Base: vw_voos_operacionais (exclui codeshares fantasma, corte >=85% cancelamento).
-- Identifica quais aeroportos de grande volume sofrem mais com sazonalidade
-- (especialmente dezembro) e quais se mantêm estáveis ao longo do ano.
--
-- LIMITAÇÃO CONHECIDA (herdada de 05_analise_companhias.sql):
-- A partir de abril/2025, o percentual de voos sem "Partida Prevista" registrada
-- sobe de ~6,5% para ~10-12%, sugerindo mudança no processo de reporte da ANAC.
-- Métricas de pontualidade/atraso para esse período devem ser interpretadas com
-- essa limitação em mente.
--
-- EXCLUSÃO: SBPA (Porto Alegre) foi excluído da visualização de heatmap
-- aeroporto×mês no dashboard por ter operação interrompida entre mai-nov/2024
-- (enchentes do RS), o que torna a agregação mensal não comparável aos demais
-- aeroportos que possuem 2 anos completos de dados. SBPA permanece nas queries
-- brutas abaixo (que usam série temporal completa, não agregação por mês do ano).

-- 1. Matriz aeroporto × mês: pontualidade e atraso para os 15 aeroportos de maior volume
-- Usa CTE para filtrar os 15 aeroportos com >5.000 voos primeiro, depois cruza com mês.
WITH top15 AS (
    SELECT "ICAO Aeródromo Origem" AS aeroporto
    FROM vw_voos_operacionais
    GROUP BY "ICAO Aeródromo Origem"
    HAVING COUNT(*) >= 5000
    ORDER BY COUNT(*) DESC
    LIMIT 15
)
SELECT
    v."ICAO Aeródromo Origem" AS aeroporto,
    v.ano_mes_referencia,
    COUNT(*) AS total_voos,
    ROUND(
        SUM(CASE WHEN v.categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
        * 100.0
        / NULLIF(SUM(CASE WHEN v.categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END), 0),
        2
    ) AS taxa_pontualidade_pct,
    ROUND(AVG(CAST(CASE WHEN v.atraso_partida_min IS NOT NULL THEN v.atraso_partida_min END AS DOUBLE)), 1) AS atraso_medio_min
FROM vw_voos_operacionais v
INNER JOIN top15 t ON v."ICAO Aeródromo Origem" = t.aeroporto
GROUP BY v."ICAO Aeródromo Origem", v.ano_mes_referencia
ORDER BY v."ICAO Aeródromo Origem", v.ano_mes_referencia;


-- 2. Variação sazonal: pior mês vs média do restante, por aeroporto
-- Identifica quais aeroportos têm queda mais acentuada em dezembro.
WITH top15 AS (
    SELECT "ICAO Aeródromo Origem" AS aeroporto
    FROM vw_voos_operacionais
    GROUP BY "ICAO Aeródromo Origem"
    HAVING COUNT(*) >= 5000
    ORDER BY COUNT(*) DESC
    LIMIT 15
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
        ) AS taxa_pontualidade_pct,
        ROUND(AVG(CAST(CASE WHEN v.atraso_partida_min IS NOT NULL THEN v.atraso_partida_min END AS DOUBLE)), 1) AS atraso_medio_min
    FROM vw_voos_operacionais v
    INNER JOIN top15 t ON v."ICAO Aeródromo Origem" = t.aeroporto
    GROUP BY v."ICAO Aeródromo Origem", CAST(SUBSTR(v.ano_mes_referencia, 6, 2) AS INTEGER)
)
SELECT
    aeroporto,
    ROUND(AVG(CASE WHEN mes != 12 THEN taxa_pontualidade_pct END), 2) AS pontualidade_media_sem_dez,
    MAX(CASE WHEN mes = 12 THEN taxa_pontualidade_pct END) AS pontualidade_dezembro,
    ROUND(
        MAX(CASE WHEN mes = 12 THEN taxa_pontualidade_pct END)
        - AVG(CASE WHEN mes != 12 THEN taxa_pontualidade_pct END),
        2
    ) AS variacao_dez_pp,
    ROUND(AVG(CASE WHEN mes != 12 THEN atraso_medio_min END), 1) AS atraso_medio_sem_dez,
    MAX(CASE WHEN mes = 12 THEN atraso_medio_min END) AS atraso_dez_min,
    ROUND(
        MAX(CASE WHEN mes = 12 THEN atraso_medio_min END)
        - AVG(CASE WHEN mes != 12 THEN atraso_medio_min END),
        1
    ) AS variacao_atraso_dez_min
FROM por_mes
GROUP BY aeroporto
ORDER BY variacao_dez_pp ASC;


-- 3. Top 10 piores combinações aeroporto+mês (entre os 15 maiores aeroportos)
-- Pior pontualidade individual em um mês específico (ano_mes_referencia).
WITH top15 AS (
    SELECT "ICAO Aeródromo Origem" AS aeroporto
    FROM vw_voos_operacionais
    GROUP BY "ICAO Aeródromo Origem"
    HAVING COUNT(*) >= 5000
    ORDER BY COUNT(*) DESC
    LIMIT 15
)
SELECT
    v."ICAO Aeródromo Origem" AS aeroporto,
    v.ano_mes_referencia,
    COUNT(*) AS total_voos,
    ROUND(
        SUM(CASE WHEN v.categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
        * 100.0
        / NULLIF(SUM(CASE WHEN v.categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END), 0),
        2
    ) AS taxa_pontualidade_pct,
    ROUND(AVG(CAST(CASE WHEN v.atraso_partida_min IS NOT NULL THEN v.atraso_partida_min END AS DOUBLE)), 1) AS atraso_medio_min
FROM vw_voos_operacionais v
INNER JOIN top15 t ON v."ICAO Aeródromo Origem" = t.aeroporto
GROUP BY v."ICAO Aeródromo Origem", v.ano_mes_referencia
ORDER BY taxa_pontualidade_pct ASC
LIMIT 10;


-- 4. Contraponto: aeroportos estáveis ou que melhoram em dezembro
-- Filtra os 15 maiores que NÃO pioram em dezembro (variação >= 0 pp).
-- Se nenhum se mantém estável, mostra os 3 com menor queda.
WITH top15 AS (
    SELECT "ICAO Aeródromo Origem" AS aeroporto
    FROM vw_voos_operacionais
    GROUP BY "ICAO Aeródromo Origem"
    HAVING COUNT(*) >= 5000
    ORDER BY COUNT(*) DESC
    LIMIT 15
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
        ) AS taxa_pontualidade_pct,
        ROUND(AVG(CAST(CASE WHEN v.atraso_partida_min IS NOT NULL THEN v.atraso_partida_min END AS DOUBLE)), 1) AS atraso_medio_min
    FROM vw_voos_operacionais v
    INNER JOIN top15 t ON v."ICAO Aeródromo Origem" = t.aeroporto
    GROUP BY v."ICAO Aeródromo Origem", CAST(SUBSTR(v.ano_mes_referencia, 6, 2) AS INTEGER)
),
variacao AS (
    SELECT
        aeroporto,
        ROUND(AVG(CASE WHEN mes != 12 THEN taxa_pontualidade_pct END), 2) AS pontualidade_media_sem_dez,
        MAX(CASE WHEN mes = 12 THEN taxa_pontualidade_pct END) AS pontualidade_dezembro,
        ROUND(
            MAX(CASE WHEN mes = 12 THEN taxa_pontualidade_pct END)
            - AVG(CASE WHEN mes != 12 THEN taxa_pontualidade_pct END),
            2
        ) AS variacao_dez_pp,
        ROUND(AVG(CASE WHEN mes != 12 THEN atraso_medio_min END), 1) AS atraso_medio_sem_dez,
        MAX(CASE WHEN mes = 12 THEN atraso_medio_min END) AS atraso_dez_min
    FROM por_mes
    GROUP BY aeroporto
)
SELECT
    aeroporto,
    pontualidade_media_sem_dez,
    pontualidade_dezembro,
    variacao_dez_pp,
    atraso_medio_sem_dez,
    atraso_dez_min
FROM variacao
ORDER BY variacao_dez_pp DESC;
