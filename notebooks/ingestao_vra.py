import glob
import os
import re
import sqlite3

import pandas as pd

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "raw")
DB_PATH = os.path.join(os.path.dirname(__file__), "..", "data", "processed", "vra.db")

DATETIME_COLS = ["Partida Prevista", "Partida Real", "Chegada Prevista", "Chegada Real"]


def extrair_ano_mes(filepath):
    match = re.search(r"VRA_(\d{4})(\d{1,2})\.csv$", filepath)
    year, month = match.group(1), match.group(2)
    return f"{year}-{int(month):02d}"


def carregar_csvs():
    files = sorted(
        glob.glob(os.path.join(RAW_DIR, "VRA_*.csv")),
        key=lambda f: (
            int(re.search(r"VRA_(\d{4})", f).group(1)),
            int(re.search(r"VRA_\d{4}(\d{1,2})\.csv", f).group(1)),
        ),
    )
    print(f"Arquivos encontrados: {len(files)}")

    dfs = []
    for f in files:
        ano_mes = extrair_ano_mes(f)
        df = pd.read_csv(f, sep=";", encoding="utf-8-sig", skiprows=1, dtype=str)
        df["ano_mes_referencia"] = ano_mes
        dfs.append(df)
        print(f"  {os.path.basename(f):25s} -> {len(df):>8,} linhas  ({ano_mes})")

    return pd.concat(dfs, ignore_index=True)


def tratar_tipos(df):
    df = df.drop(columns=["Código Justificativa"])

    for col in DATETIME_COLS:
        df[col] = pd.to_datetime(df[col], format="%Y-%m-%d %H:%M:%S", errors="coerce")

    return df


def salvar_sqlite(df):
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)
    df.to_sql("voos", conn, if_exists="replace", index=False)

    print(f"\nSalvo em: {DB_PATH}")
    print(f"Registros na tabela 'voos': {len(df):,}")

    print("\n=== CONFERENCIA ===")
    query = """
        SELECT
            COUNT(*) AS total_registros,
            MIN("Partida Prevista") AS data_minima,
            MAX("Partida Prevista") AS data_maxima
        FROM voos
        WHERE "Partida Prevista" IS NOT NULL
    """
    result = pd.read_sql(query, conn)
    print(result.to_string(index=False))

    conn.close()


if __name__ == "__main__":
    print("== INGESTAO VRA ==\n")

    df = carregar_csvs()
    print(f"\nTotal concatenado: {len(df):,} linhas")

    df = tratar_tipos(df)
    print(f"Apos tratamento:   {len(df):,} linhas, {df.shape[1]} colunas")

    salvar_sqlite(df)
