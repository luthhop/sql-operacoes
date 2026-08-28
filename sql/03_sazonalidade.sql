-- Análise de sazonalidade — VRA (ANAC)
-- Pontualidade, cancelamento e atraso por mês e dia da semana.

-- 1a. Taxa de pontualidade e cancelamento por MÊS DO ANO (agregado)
SELECT
    CAST(SUBSTR(ano_mes_referencia, 6, 2) AS INTEGER) AS mes,
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
GROUP BY mes
ORDER BY mes;


-- 1b. Série temporal completa: ano + mês
SELECT
    ano_mes_referencia,
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
GROUP BY ano_mes_referencia
ORDER BY ano_mes_referencia;


-- 2. Taxa de pontualidade e cancelamento por DIA DA SEMANA
-- strftime('%w') retorna 0=domingo, 1=segunda ... 6=sábado.
-- Exclui registros sem Partida Prevista.
SELECT
    CAST(strftime('%w', "Partida Prevista") AS INTEGER) AS dia_semana_num,
    CASE strftime('%w', "Partida Prevista")
        WHEN '0' THEN 'Domingo'
        WHEN '1' THEN 'Segunda'
        WHEN '2' THEN 'Terca'
        WHEN '3' THEN 'Quarta'
        WHEN '4' THEN 'Quinta'
        WHEN '5' THEN 'Sexta'
        WHEN '6' THEN 'Sabado'
    END AS dia_semana,
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
WHERE "Partida Prevista" IS NOT NULL
GROUP BY dia_semana_num
ORDER BY dia_semana_num;


-- 3. Pior mês e pior dia da semana (maior atraso médio)
-- Pior mês (ano+mês)
SELECT
    ano_mes_referencia,
    ROUND(AVG(CASE WHEN atraso_partida_min IS NOT NULL THEN atraso_partida_min END), 1) AS atraso_medio_min
FROM vw_voos_analitico
GROUP BY ano_mes_referencia
ORDER BY atraso_medio_min DESC
LIMIT 1;

-- Pior dia da semana
SELECT
    CASE strftime('%w', "Partida Prevista")
        WHEN '0' THEN 'Domingo'
        WHEN '1' THEN 'Segunda'
        WHEN '2' THEN 'Terca'
        WHEN '3' THEN 'Quarta'
        WHEN '4' THEN 'Quinta'
        WHEN '5' THEN 'Sexta'
        WHEN '6' THEN 'Sabado'
    END AS dia_semana,
    ROUND(AVG(CASE WHEN atraso_partida_min IS NOT NULL THEN atraso_partida_min END), 1) AS atraso_medio_min
FROM vw_voos_analitico
WHERE "Partida Prevista" IS NOT NULL
GROUP BY dia_semana
ORDER BY atraso_medio_min DESC
LIMIT 1;


-- 4. Taxa de cancelamento por mês (série temporal isolada)
SELECT
    ano_mes_referencia,
    COUNT(*) AS total_voos,
    SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END) AS cancelados,
    ROUND(
        SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS taxa_cancelamento_pct
FROM vw_voos_analitico
GROUP BY ano_mes_referencia
ORDER BY ano_mes_referencia;
