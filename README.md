# SQL Operacoes

Analisar dados publicos de voos da aviacao civil brasileira (ANAC) para identificar padroes de atraso e cancelamento por companhia aerea, aeroporto e periodo, usando SQL para consultas analiticas e Streamlit para visualizacao de KPIs operacionais.

## Status

Em desenvolvimento — Fase de analise SQL concluida

## O que foi feito ate aqui

- Ingestao de ~2 milhoes de registros de voos (ANAC, VRA, 2024-2025) em SQLite (`notebooks/ingestao_vra.py`)
- View analitica com categorizacao de atraso segundo faixas oficiais da ANAC (`sql/01_view_voos_analitico.sql`)
- View operacional com exclusao de codeshares/autorizacoes nao operadas (`sql/00_view_voos_operacionais.sql`)
- KPIs gerais: pontualidade 90,87%, cancelamento 3,49% (`sql/02_kpis_gerais.sql`)
- Analise de sazonalidade: dezembro e o pior mes, sexta o pior dia da semana (`sql/03_sazonalidade.sql`)
- Analise por aeroporto, com identificacao e exclusao de codeshares/autorizacoes nao operadas que distorciam o ranking (`sql/04_analise_aeroportos.sql`)
- Analise por companhia aerea, com tratamento de operadoras de carga e limitacao de dados documentada a partir de abril/2025 (`sql/05_analise_companhias.sql`)

## Achados principais ate agora

- Pontualidade geral de ~91%, com melhora consistente de 2024 para 2025
- Dezembro e sazonalmente o pior mes em toda a serie
- Aeroportos domesticos de grande porte (ex: Brasilia) superam varios hubs internacionais em pontualidade, uma vez removido o ruido de registros nao operados
- O proprio processo de auditoria dos dados (deteccao de bugs de categorizacao, codeshares fantasma e lacunas de reporte) e parte relevante da entrega do projeto

## Proximos passos

- [ ] Analise de cruzamento (ex: pior combinacao aeroporto + periodo)
- [ ] Dashboard Streamlit
- [ ] Post de divulgacao no LinkedIn

## Stack

- Python
- Pandas
- SQL
- Streamlit
- Git/GitHub

## Decisoes e correcoes

- **2026-08-28 — Mudanca de escopo**: O escopo inicial do projeto era baseado no dataset Olist (e-commerce). Foi alterado para dados de aviacao civil (ANAC) para evitar sobreposicao com outro projeto de portfolio ja existente (brazilian-ecommerce-analytics) e para explorar um dominio mais alinhado a experiencia previa em operacoes.
- **2026-08-28 — Correcao na view analitica**: Durante a validacao da view `vw_voos_analitico`, foi identificado que ~118 mil voos realizados sem horario de partida/chegada previsto registrado estavam sendo classificados incorretamente como "Atraso > 240" por uma falha no CASE WHEN. Corrigido com uma categoria propria "Sem horario previsto", separando dado incompleto de atraso real.
