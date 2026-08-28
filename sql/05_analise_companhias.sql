-- Análise por companhia aérea — VRA (ANAC)
-- Base: vw_voos_operacionais (exclui codeshares fantasma, corte >=85% cancelamento).
--
-- LIMITAÇÃO CONHECIDA:
-- A partir de abril/2025, o percentual de voos sem "Partida Prevista" registrada
-- salta de ~6,5% para ~10-12% e permanece nesse patamar até dezembro/2025 (fim
-- da série), o dobro do padrão histórico observado entre mar/2024 e mar/2025
-- (~2,5-6,5%). Esse aumento é amplo (afeta o dataset agregado, não só empresas
-- específicas) e sustentado por 9 meses consecutivos, sugerindo mudança na fonte
-- ou no processo de reporte da ANAC a partir dessa data, não apenas atraso de
-- consolidação do mês mais recente. Adicionalmente, dentro desse período, certas
-- companhias internacionais menores (AFR, ETH, THY) apresentam 95-100% dos voos
-- de dezembro/2025 sem horário previsto — um problema mais severo e concentrado,
-- já mitigado pelo filtro de completude mínima de 50% aplicado nas queries deste
-- arquivo. Métricas agregadas para o período abril/2025-dezembro/2025 devem ser
-- interpretadas com essa limitação em mente.
--
-- Empresas com menos de 50% de registros com horário previsto/real completo
-- foram excluídas dos rankings (queries 2a-2d) — geralmente operadoras de carga
-- com padrão de escala multi-dia, onde a métrica de atraso ponto-a-ponto não
-- se aplica.

-- 1. Top 15 companhias por volume de voos
SELECT
    "ICAO Empresa Aérea" AS empresa,
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
FROM vw_voos_operacionais
GROUP BY empresa
ORDER BY total_voos DESC
LIMIT 15;


-- 2a. Melhores em pontualidade (mínimo 5.000 voos, >=50% registros com atraso calculável)
SELECT
    "ICAO Empresa Aérea" AS empresa,
    COUNT(*) AS total_voos,
    ROUND(
        SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
        * 100.0
        / SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END),
        2
    ) AS taxa_pontualidade_pct,
    ROUND(AVG(CASE WHEN atraso_partida_min IS NOT NULL THEN atraso_partida_min END), 1) AS atraso_medio_min
FROM vw_voos_operacionais
GROUP BY empresa
HAVING COUNT(*) >= 5000
   AND SUM(CASE WHEN atraso_partida_min IS NOT NULL THEN 1 ELSE 0 END) * 1.0 / COUNT(*) >= 0.5
ORDER BY taxa_pontualidade_pct DESC
LIMIT 10;


-- 2b. Piores em pontualidade (mínimo 5.000 voos, >=50% registros com atraso calculável)
SELECT
    "ICAO Empresa Aérea" AS empresa,
    COUNT(*) AS total_voos,
    ROUND(
        SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
        * 100.0
        / SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END),
        2
    ) AS taxa_pontualidade_pct,
    ROUND(AVG(CASE WHEN atraso_partida_min IS NOT NULL THEN atraso_partida_min END), 1) AS atraso_medio_min
FROM vw_voos_operacionais
GROUP BY empresa
HAVING COUNT(*) >= 5000
   AND SUM(CASE WHEN atraso_partida_min IS NOT NULL THEN 1 ELSE 0 END) * 1.0 / COUNT(*) >= 0.5
ORDER BY taxa_pontualidade_pct ASC
LIMIT 10;


-- 2c. Maior taxa de cancelamento (mínimo 5.000 voos, >=50% registros com atraso calculável)
SELECT
    "ICAO Empresa Aérea" AS empresa,
    COUNT(*) AS total_voos,
    SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END) AS cancelados,
    ROUND(
        SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS taxa_cancelamento_pct
FROM vw_voos_operacionais
GROUP BY empresa
HAVING COUNT(*) >= 5000
   AND SUM(CASE WHEN atraso_partida_min IS NOT NULL THEN 1 ELSE 0 END) * 1.0 / COUNT(*) >= 0.5
ORDER BY taxa_cancelamento_pct DESC
LIMIT 10;


-- 2d. Maior atraso médio (mínimo 5.000 voos, >=50% registros com atraso calculável)
SELECT
    "ICAO Empresa Aérea" AS empresa,
    COUNT(*) AS total_voos,
    ROUND(AVG(CASE WHEN atraso_partida_min IS NOT NULL THEN atraso_partida_min END), 1) AS atraso_medio_min,
    ROUND(
        SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
        * 100.0
        / SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END),
        2
    ) AS taxa_pontualidade_pct
FROM vw_voos_operacionais
GROUP BY empresa
HAVING COUNT(*) >= 5000
   AND SUM(CASE WHEN atraso_partida_min IS NOT NULL THEN 1 ELSE 0 END) * 1.0 / COUNT(*) >= 0.5
ORDER BY atraso_medio_min DESC
LIMIT 10;


-- 3. Sazonalidade por companhia: pontualidade em dezembro vs média anual
-- Calcula a queda de pontualidade em dezembro para cada companhia.
SELECT
    empresa,
    total_voos,
    pontualidade_media_anual,
    pontualidade_dezembro,
    ROUND(pontualidade_dezembro - pontualidade_media_anual, 2) AS variacao_dez_pp
FROM (
    SELECT
        "ICAO Empresa Aérea" AS empresa,
        COUNT(*) AS total_voos,
        ROUND(
            SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado')
                      AND SUBSTR(ano_mes_referencia, 6, 2) != '12'
                 THEN 1 ELSE 0 END)
            * 100.0
            / NULLIF(SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto')
                              AND SUBSTR(ano_mes_referencia, 6, 2) != '12'
                         THEN 1 ELSE 0 END), 0),
            2
        ) AS pontualidade_media_anual,
        ROUND(
            SUM(CASE WHEN categoria_atraso_partida IN ('Pontual', 'Antecipado')
                      AND SUBSTR(ano_mes_referencia, 6, 2) = '12'
                 THEN 1 ELSE 0 END)
            * 100.0
            / NULLIF(SUM(CASE WHEN categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto')
                              AND SUBSTR(ano_mes_referencia, 6, 2) = '12'
                         THEN 1 ELSE 0 END), 0),
            2
        ) AS pontualidade_dezembro
    FROM vw_voos_operacionais
    GROUP BY empresa
    HAVING COUNT(*) >= 5000
)
ORDER BY variacao_dez_pp ASC;


-- 4. Evolução 2024 vs 2025 por companhia
SELECT
    "ICAO Empresa Aérea" AS empresa,
    SUM(CASE WHEN SUBSTR(ano_mes_referencia, 1, 4) = '2024' THEN 1 ELSE 0 END) AS voos_2024,
    SUM(CASE WHEN SUBSTR(ano_mes_referencia, 1, 4) = '2025' THEN 1 ELSE 0 END) AS voos_2025,
    ROUND(
        SUM(CASE WHEN SUBSTR(ano_mes_referencia, 1, 4) = '2024'
                  AND categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
        * 100.0
        / NULLIF(SUM(CASE WHEN SUBSTR(ano_mes_referencia, 1, 4) = '2024'
                          AND categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END), 0),
        2
    ) AS pontualidade_2024,
    ROUND(
        SUM(CASE WHEN SUBSTR(ano_mes_referencia, 1, 4) = '2025'
                  AND categoria_atraso_partida IN ('Pontual', 'Antecipado') THEN 1 ELSE 0 END)
        * 100.0
        / NULLIF(SUM(CASE WHEN SUBSTR(ano_mes_referencia, 1, 4) = '2025'
                          AND categoria_atraso_partida NOT IN ('Cancelado', 'Sem horário previsto') THEN 1 ELSE 0 END), 0),
        2
    ) AS pontualidade_2025,
    ROUND(
        SUM(CASE WHEN SUBSTR(ano_mes_referencia, 1, 4) = '2024'
                  AND "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
        * 100.0
        / NULLIF(SUM(CASE WHEN SUBSTR(ano_mes_referencia, 1, 4) = '2024' THEN 1 ELSE 0 END), 0),
        2
    ) AS cancelamento_2024,
    ROUND(
        SUM(CASE WHEN SUBSTR(ano_mes_referencia, 1, 4) = '2025'
                  AND "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
        * 100.0
        / NULLIF(SUM(CASE WHEN SUBSTR(ano_mes_referencia, 1, 4) = '2025' THEN 1 ELSE 0 END), 0),
        2
    ) AS cancelamento_2025
FROM vw_voos_operacionais
GROUP BY empresa
HAVING COUNT(*) >= 5000
ORDER BY (pontualidade_2025 - pontualidade_2024) DESC;
