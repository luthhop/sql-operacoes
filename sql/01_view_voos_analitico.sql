-- View analítica sobre a tabela de voos VRA (ANAC).
-- Adiciona colunas calculadas de atraso em minutos e categorização
-- conforme faixas oficiais do dicionário de dados VRA.
-- Datas armazenadas como TEXT ISO-8601; aritmética via julianday().

DROP VIEW IF EXISTS vw_voos_analitico;

CREATE VIEW vw_voos_analitico AS
SELECT
    *,

    -- Atraso na partida em minutos (positivo = atrasou, negativo = antecipou)
    ROUND(
        (julianday("Partida Real") - julianday("Partida Prevista")) * 1440
    ) AS atraso_partida_min,

    -- Atraso na chegada em minutos
    ROUND(
        (julianday("Chegada Real") - julianday("Chegada Prevista")) * 1440
    ) AS atraso_chegada_min,

    -- Categorização do atraso na partida (faixas oficiais ANAC)
    CASE
        WHEN "Partida Real" IS NULL THEN 'Cancelado'
        WHEN ROUND((julianday("Partida Real") - julianday("Partida Prevista")) * 1440) < 0
            THEN 'Antecipado'
        WHEN ROUND((julianday("Partida Real") - julianday("Partida Prevista")) * 1440) < 30
            THEN 'Pontual'
        WHEN ROUND((julianday("Partida Real") - julianday("Partida Prevista")) * 1440) < 60
            THEN 'Atraso 30-60'
        WHEN ROUND((julianday("Partida Real") - julianday("Partida Prevista")) * 1440) < 120
            THEN 'Atraso 60-120'
        WHEN ROUND((julianday("Partida Real") - julianday("Partida Prevista")) * 1440) < 240
            THEN 'Atraso 120-240'
        ELSE 'Atraso > 240'
    END AS categoria_atraso_partida,

    -- Categorização do atraso na chegada (mesmas faixas)
    CASE
        WHEN "Chegada Real" IS NULL THEN 'Cancelado'
        WHEN ROUND((julianday("Chegada Real") - julianday("Chegada Prevista")) * 1440) < 0
            THEN 'Antecipado'
        WHEN ROUND((julianday("Chegada Real") - julianday("Chegada Prevista")) * 1440) < 30
            THEN 'Pontual'
        WHEN ROUND((julianday("Chegada Real") - julianday("Chegada Prevista")) * 1440) < 60
            THEN 'Atraso 30-60'
        WHEN ROUND((julianday("Chegada Real") - julianday("Chegada Prevista")) * 1440) < 120
            THEN 'Atraso 60-120'
        WHEN ROUND((julianday("Chegada Real") - julianday("Chegada Prevista")) * 1440) < 240
            THEN 'Atraso 120-240'
        ELSE 'Atraso > 240'
    END AS categoria_atraso_chegada,

    -- Flag: voo operado no dia seguinte ao previsto (atraso > 24h)
    CASE
        WHEN ROUND((julianday("Partida Real") - julianday("Partida Prevista")) * 1440) > 1440
            THEN TRUE
        ELSE FALSE
    END AS operado_dia_seguinte

FROM voos;
