-- View operacional filtrada — VRA (ANAC)
--
-- Esta view remove combinações aeroporto+empresa com >=85% de cancelamento,
-- identificadas como provável registro de autorização/codeshare não operado
-- (ver sql/04_analise_aeroportos.sql para a auditoria completa).
-- Corte ajustado de 95% para 85% após identificar caso ETH-DNMM (85,86%
-- cancelamento, 1.188 voos) com mesmo padrão de codeshare fantasma.
-- Use esta view para qualquer análise agregada por empresa ou cruzamento —
-- use vw_voos_analitico apenas para auditoria/dados brutos completos.

DROP VIEW IF EXISTS vw_voos_operacionais;

CREATE VIEW vw_voos_operacionais AS
SELECT *
FROM vw_voos_analitico
WHERE ("ICAO Aeródromo Origem", "ICAO Empresa Aérea") NOT IN (
    SELECT "ICAO Aeródromo Origem", "ICAO Empresa Aérea"
    FROM vw_voos_analitico
    GROUP BY "ICAO Aeródromo Origem", "ICAO Empresa Aérea"
    HAVING SUM(CASE WHEN "Situação Voo" = 'CANCELADO' THEN 1 ELSE 0 END)
           * 100.0 / COUNT(*) >= 85
);
