-- Análise por aeroporto — VRA (ANAC)
-- Ranking de volume, pontualidade, cancelamento e atraso por aeroporto.
--
-- DECISÃO DE LIMPEZA:
-- Combinações aeroporto+empresa com >=95% de cancelamento foram excluídas
-- da análise de desempenho por aeroporto (queries 5b em diante), pois
-- representam provável registro de autorização/codeshare não operado,
-- não gargalo operacional real. Essas combinações estão listadas na
-- query de auditoria 5a deste arquivo.

-- 1. Top 15 aeroportos de ORIGEM por volume de voos
SELECT
    "ICAO Aeródromo Origem" AS aeroporto,
    COUNT(*) AS total_voos,
    ROUND(
        SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
        * 100.0
        / SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END),
        2
    ) AS taxa_pontualidade_pct,
    ROUND(
        SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS taxa_cancelamento_pct,
    ROUND(AVG(CASE WHEN atraso_partida_min IS NOT NULL THEN atraso_partida_min END), 1) AS atraso_medio_min
FROM vw_voos_analitico
GROUP BY aeroporto
ORDER BY total_voos DESC
LIMIT 15;


-- 2a. Aeroportos de ORIGEM com pior pontualidade (mínimo 5.000 voos)
SELECT
    "ICAO Aeródromo Origem" AS aeroporto,
    COUNT(*) AS total_voos,
    ROUND(
        SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
        * 100.0
        / SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END),
        2
    ) AS taxa_pontualidade_pct,
    ROUND(
        SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS taxa_cancelamento_pct,
    ROUND(AVG(CASE WHEN atraso_partida_min IS NOT NULL THEN atraso_partida_min END), 1) AS atraso_medio_min
FROM vw_voos_analitico
GROUP BY aeroporto
HAVING COUNT(*) >= 5000
ORDER BY taxa_pontualidade_pct ASC
LIMIT 10;


-- 2b. Aeroportos de ORIGEM com maior taxa de cancelamento (mínimo 5.000 voos)
SELECT
    "ICAO Aeródromo Origem" AS aeroporto,
    COUNT(*) AS total_voos,
    SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END) AS cancelados,
    ROUND(
        SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS taxa_cancelamento_pct
FROM vw_voos_analitico
GROUP BY aeroporto
HAVING COUNT(*) >= 5000
ORDER BY taxa_cancelamento_pct DESC
LIMIT 10;


-- 2c. Aeroportos de ORIGEM com maior atraso médio (mínimo 5.000 voos)
SELECT
    "ICAO Aeródromo Origem" AS aeroporto,
    COUNT(*) AS total_voos,
    ROUND(AVG(CASE WHEN atraso_partida_min IS NOT NULL THEN atraso_partida_min END), 1) AS atraso_medio_min,
    ROUND(
        SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
        * 100.0
        / SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END),
        2
    ) AS taxa_pontualidade_pct
FROM vw_voos_analitico
GROUP BY aeroporto
HAVING COUNT(*) >= 5000
ORDER BY atraso_medio_min DESC
LIMIT 10;


-- 3. Aeroportos de DESTINO: pior pontualidade na chegada (mínimo 5.000 voos)
SELECT
    "ICAO Aeródromo Destino" AS aeroporto,
    COUNT(*) AS total_voos,
    ROUND(
        SUM(CASE WHEN categoria_atraso_chegada IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
        * 100.0
        / SUM(CASE WHEN categoria_atraso_chegada NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END),
        2
    ) AS taxa_pontualidade_chegada_pct,
    ROUND(
        SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS taxa_cancelamento_pct,
    ROUND(AVG(CASE WHEN atraso_chegada_min IS NOT NULL THEN atraso_chegada_min END), 1) AS atraso_medio_chegada_min
FROM vw_voos_analitico
GROUP BY aeroporto
HAVING COUNT(*) >= 5000
ORDER BY taxa_pontualidade_chegada_pct ASC
LIMIT 10;


-- 4. Cruzamento: volume vs desempenho na origem
SELECT
    aeroporto,
    total_voos,
    rank_volume,
    taxa_pontualidade_pct,
    rank_pontualidade,
    atraso_medio_min
FROM (
    SELECT
        "ICAO Aeródromo Origem" AS aeroporto,
        COUNT(*) AS total_voos,
        RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_volume,
        ROUND(
            SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
            * 100.0
            / SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END),
            2
        ) AS taxa_pontualidade_pct,
        RANK() OVER (
            ORDER BY
            SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
            * 1.0
            / SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END)
            ASC
        ) AS rank_pontualidade,
        ROUND(AVG(CASE WHEN atraso_partida_min IS NOT NULL THEN atraso_partida_min END), 1) AS atraso_medio_min
    FROM vw_voos_analitico
    GROUP BY aeroporto
    HAVING COUNT(*) >= 5000
)
ORDER BY rank_pontualidade ASC
LIMIT 15;


-- 5a. AUDITORIA: combinações aeroporto+empresa com >=95% de cancelamento
SELECT
    "ICAO Aeródromo Origem" AS aeroporto,
    "ICAO Empresa Aérea" AS empresa,
    COUNT(*) AS total_voos,
    SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END) AS cancelados,
    ROUND(
        SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS taxa_cancelamento_pct
FROM vw_voos_analitico
GROUP BY aeroporto, empresa
HAVING taxa_cancelamento_pct >= 95
ORDER BY total_voos DESC;


-- 5b. Ranking LIMPO: pior pontualidade na origem (excluindo codeshares fantasma)
SELECT
    "ICAO Aeródromo Origem" AS aeroporto,
    COUNT(*) AS total_voos,
    ROUND(
        SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
        * 100.0
        / SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END),
        2
    ) AS taxa_pontualidade_pct,
    ROUND(
        SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS taxa_cancelamento_pct,
    ROUND(AVG(CASE WHEN atraso_partida_min IS NOT NULL THEN atraso_partida_min END), 1) AS atraso_medio_min
FROM vw_voos_analitico
WHERE ("ICAO Aeródromo Origem", "ICAO Empresa Aérea") NOT IN (
    SELECT "ICAO Aeródromo Origem", "ICAO Empresa Aérea"
    FROM vw_voos_analitico
    GROUP BY "ICAO Aeródromo Origem", "ICAO Empresa Aérea"
    HAVING SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 95
)
GROUP BY aeroporto
HAVING COUNT(*) >= 5000
ORDER BY taxa_pontualidade_pct ASC
LIMIT 10;


-- 5c. Ranking LIMPO: maior taxa de cancelamento na origem (excluindo codeshares fantasma)
SELECT
    "ICAO Aeródromo Origem" AS aeroporto,
    COUNT(*) AS total_voos,
    SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END) AS cancelados,
    ROUND(
        SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS taxa_cancelamento_pct
FROM vw_voos_analitico
WHERE ("ICAO Aeródromo Origem", "ICAO Empresa Aérea") NOT IN (
    SELECT "ICAO Aeródromo Origem", "ICAO Empresa Aérea"
    FROM vw_voos_analitico
    GROUP BY "ICAO Aeródromo Origem", "ICAO Empresa Aérea"
    HAVING SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 95
)
GROUP BY aeroporto
HAVING COUNT(*) >= 5000
ORDER BY taxa_cancelamento_pct DESC
LIMIT 10;
