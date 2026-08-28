-- KPIs gerais de pontualidade e cancelamento — VRA (ANAC)
-- Todas as queries usam a view vw_voos_analitico como base.

-- 1. Taxa de pontualidade geral
-- Denominador exclui "Cancelado" e "Sem horário previsto"
-- (só voos com categoria de atraso calculável são comparáveis).
SELECT
    COUNT(*) AS total_voos_comparaveis,
    SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END) AS pontuais,
    ROUND(
        SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS taxa_pontualidade_pct
FROM vw_voos_analitico
WHERE categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto');


-- 2. Taxa de cancelamento geral
-- Denominador inclui todos os voos (cancelamento é resultado possível).
SELECT
    COUNT(*) AS total_voos,
    SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END) AS cancelados,
    ROUND(
        SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS taxa_cancelamento_pct
FROM vw_voos_analitico;


-- 3. Atraso médio e mediano de partida (em minutos)
-- Considera apenas voos com atraso calculável (exclui cancelados e sem previsão).
SELECT
    COUNT(*) AS total_voos,
    ROUND(AVG(atraso_partida_min), 1) AS atraso_medio_min,
    (
        SELECT atraso_partida_min
        FROM vw_voos_analitico
        WHERE atraso_partida_min IS NOT NULL
        ORDER BY atraso_partida_min
        LIMIT 1 OFFSET (
            SELECT COUNT(*) / 2
            FROM vw_voos_analitico
            WHERE atraso_partida_min IS NOT NULL
        )
    ) AS atraso_mediano_min
FROM vw_voos_analitico
WHERE atraso_partida_min IS NOT NULL;


-- 4. Distribuição percentual por categoria de atraso na partida
SELECT
    categoria_atraso_partida,
    COUNT(*) AS total,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM vw_voos_analitico), 2) AS pct_do_total
FROM vw_voos_analitico
GROUP BY categoria_atraso_partida
ORDER BY total DESC;


-- 5. Comparativo 2024 vs 2025: pontualidade e cancelamento por ano
SELECT
    SUBSTR(ano_mes_referencia, 1, 4) AS ano,
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
    ROUND(
        AVG(CASE WHEN atraso_partida_min IS NOT NULL THEN atraso_partida_min END), 1
    ) AS atraso_medio_min
FROM vw_voos_analitico
GROUP BY ano
ORDER BY ano;
