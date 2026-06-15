---
name: postgres-dba
description: >
  Administração e diagnóstico de PostgreSQL: queries lentas, locks,
  bloat, índices, conexões, vacuum. Invocar para qualquer tarefa de
  análise ou tuning de banco PostgreSQL.
---

# PostgreSQL DBA

## Guardrails

- Diagnóstico é SELECT — nunca rode DDL/DML em produção sem ADR + aprovação
- Antes de propor índice: `EXPLAIN (ANALYZE, BUFFERS)` da query real
- Mudança estrutural (índice, partição, parâmetro) → via migration
  versionada, nunca psql manual em prod
- `CREATE INDEX CONCURRENTLY` em prod (não bloqueia writes)

## Diagnóstico — queries prontas (use estas, não invente)

### Conexões e atividade agora
```sql
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;
SELECT pid, usename, state, wait_event_type, now()-query_start AS dur,
       left(query, 80) AS query
FROM pg_stat_activity
WHERE state != 'idle' ORDER BY dur DESC LIMIT 20;
```

### Locks bloqueando
```sql
SELECT blocked.pid AS blocked_pid, blocked.query AS blocked_query,
       blocking.pid AS blocking_pid, blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_locks bl ON bl.pid = blocked.pid AND NOT bl.granted
JOIN pg_locks gl ON gl.locktype = bl.locktype
  AND gl.database IS NOT DISTINCT FROM bl.database
  AND gl.relation IS NOT DISTINCT FROM bl.relation
  AND gl.granted
JOIN pg_stat_activity blocking ON blocking.pid = gl.pid;
```

### Top queries por tempo total (requer pg_stat_statements)
```sql
SELECT round(total_exec_time::numeric, 1) AS total_ms, calls,
       round(mean_exec_time::numeric, 2) AS mean_ms,
       left(query, 80) AS query
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 15;
```

### Índices não usados (candidatos a remoção — confirme antes!)
```sql
SELECT schemaname, relname, indexrelname, idx_scan,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0 ORDER BY pg_relation_size(indexrelid) DESC LIMIT 15;
```

### Tabelas com mais sequential scans (candidatas a índice)
```sql
SELECT relname, seq_scan, seq_tup_read, idx_scan,
       pg_size_pretty(pg_total_relation_size(relid)) AS size
FROM pg_stat_user_tables
WHERE seq_scan > 0 ORDER BY seq_tup_read DESC LIMIT 15;
```

### Bloat aproximado / vacuum atrasado
```sql
SELECT relname, n_dead_tup, n_live_tup,
       round(n_dead_tup * 100.0 / nullif(n_live_tup + n_dead_tup, 0), 1) AS dead_pct,
       last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000 ORDER BY n_dead_tup DESC LIMIT 15;
```

## Método para "query lenta"

1. Capture a query EXATA (pg_stat_statements ou logs)
2. `EXPLAIN (ANALYZE, BUFFERS)` — procure: Seq Scan em tabela grande,
   rows estimado vs real muito divergente (estatísticas velhas →
   `ANALYZE tabela`), Sort/Hash spillando pra disco
3. Proponha correção COM evidência do plano
4. Índice novo? Estime tamanho e impacto em writes antes
