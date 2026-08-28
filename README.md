# SQL Operacoes

Analisar dados publicos de voos da aviacao civil brasileira (ANAC) para identificar padroes de atraso e cancelamento por companhia aerea, aeroporto e periodo, usando SQL para consultas analiticas e Streamlit para visualizacao de KPIs operacionais.

## Status

Em desenvolvimento

## Stack

- Python
- Pandas
- SQL
- Streamlit
- Git/GitHub

## Proximos passos

- [ ] Obter dados da ANAC
- [ ] Explorar e tratar os dados
- [ ] Modelar em SQL
- [ ] Construir queries analiticas
- [ ] Construir dashboard Streamlit

## Decisoes e correcoes

- **2026-08-28 — Mudanca de escopo**: O escopo inicial do projeto era baseado no dataset Olist (e-commerce). Foi alterado para dados de aviacao civil (ANAC) para evitar sobreposicao com outro projeto de portfolio ja existente (brazilian-ecommerce-analytics) e para explorar um dominio mais alinhado a experiencia previa em operacoes.
- **2026-08-28 — Correcao na view analitica**: Durante a validacao da view `vw_voos_analitico`, foi identificado que ~118 mil voos realizados sem horario de partida/chegada previsto registrado estavam sendo classificados incorretamente como "Atraso > 240" por uma falha no CASE WHEN. Corrigido com uma categoria propria "Sem horario previsto", separando dado incompleto de atraso real.
