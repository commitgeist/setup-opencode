# Documentação Operacional — Conceitos

> Referência rápida: ADR, Runbook, Playbook e Postmortem.
> Cada um resolve um problema diferente. Use o certo na hora certa.

---

## Visão geral

```
     ANTES de agir          DURANTE a execução        DEPOIS do incidente
    ┌──────────────┐       ┌──────────────────┐       ┌──────────────────┐
    │     ADR      │       │     RUNBOOK      │       │   POSTMORTEM     │
    │  "O que e    │       │  "Passo a passo  │       │  "O que deu      │
    │   por quê"   │       │   pra executar"  │       │   errado e como  │
    └──────────────┘       └──────────────────┘       │   evitar"        │
                           ┌──────────────────┐       └──────────────────┘
                           │    PLAYBOOK      │
                           │  "Estratégia     │
                           │   pra cenários"  │
                           └──────────────────┘
```

---

## ADR — Architecture Decision Record

### O que é
Documento que registra uma **decisão técnica**: o quê foi decidido, por quê,
quais alternativas foram descartadas e como implementar.

### Quando usar
- Mudança de arquitetura (trocar IaC tool, mudar cloud, reestruturar pipelines)
- Nova convenção ou padrão que afeta o time
- Decisão que alguém vai perguntar "por que fizemos assim?" daqui a 6 meses
- Trade-off significativo entre alternativas

### Quando NÃO usar
- Bug fix, task operacional de rotina
- Mudança trivial sem trade-offs

### Exemplo (infra)
```
ADR-0003: Migrar state do Terraform para S3 com locking via DynamoDB

Contexto: state local causa conflitos quando dois engenheiros rodam plan.
Decisão: backend S3 + DynamoDB lock.
Alternativas: Terraform Cloud (custo), GitLab managed state (vendor lock).
```

### Ciclo de vida
```
Proposed → Approved → Implemented → Archived/Superseded
```

> Já tem template em `docs/adr/TEMPLATE.md` — use o command `/new-adr`.

---

## Runbook — Procedimento Operacional

### O que é
Documento com **passo a passo exato** para executar uma tarefa operacional.
Escrito para que qualquer pessoa do time consiga seguir, mesmo às 3h da manhã.

### Quando usar
- Tarefa operacional que se repete (deploy, rollback, rotação de secrets)
- Procedimento de emergência (escalar cluster, failover de banco)
- Onboarding: "como fazer X no nosso ambiente"
- Qualquer coisa que hoje vive "na cabeça de uma pessoa"

### Quando NÃO usar
- Decisões de design (use ADR)
- Análise de incidente passado (use Postmortem)

### Estrutura típica
```markdown
# Runbook: Rollback de deploy ECS

## Quando usar
Deploy com erro em produção, após validação do health check falhar.

## Pré-requisitos
- Acesso AWS com role X
- CLI aws configurada
- Cluster e service name em mãos

## Passos
1. Identificar a revision anterior:
   `aws ecs describe-services --cluster X --services Y --query 'services[0].taskDefinition'`
2. Obter a revision N-1:
   `aws ecs list-task-definitions --family-prefix Y --sort DESC --max-items 2`
3. Atualizar o service para a revision anterior:
   `aws ecs update-service --cluster X --service Y --task-definition Y:N-1`
4. Aguardar estabilização:
   `aws ecs wait services-stable --cluster X --services Y`
5. Validar:
   `curl -s https://api.exemplo.com/health | jq .status`

## Troubleshooting
- Se o wait timeout: verificar eventos do service com `aws ecs describe-services`
- Se a revision anterior também falha: escalar para o time de dev

## Quem contactar
- Plantão DevOps: #channel-ops
- Escalação: @fulano
```

### Onde guardar
```
docs/runbooks/
  rollback-ecs.md
  rotacionar-secrets.md
  escalar-cluster-aks.md
```

---

## Playbook — Estratégia para Cenários

### O que é
Documento de **estratégia e processo** para lidar com uma categoria de situação.
Diferente do Runbook (que é um passo-a-passo técnico), o Playbook define o
**framework de decisão**: quem faz o quê, em que ordem, e como escalar.

### Quando usar
- Resposta a incidentes (quem lidera, quem comunica, quem investiga)
- Processo de release (etapas, gates, rollback criteria)
- Onboarding de nova aplicação no cluster
- Disaster recovery (RTO/RPO, ordem de restauração)
- Qualquer cenário onde **múltiplas pessoas/times coordenam**

### Quando NÃO usar
- Tarefa técnica individual (use Runbook)
- Decisão de design (use ADR)

### Diferença Runbook vs Playbook

| | Runbook | Playbook |
|---|---|---|
| **Escopo** | Uma tarefa específica | Uma categoria de cenário |
| **Foco** | Comandos e passos técnicos | Processo, papéis, decisão |
| **Autor** | Quem sabe fazer | Quem define o processo |
| **Exemplo** | "Rollback do deploy ECS" | "Resposta a incidentes P1" |
| **Analogia** | Receita de bolo | Manual do chef de cozinha |

### Estrutura típica
```markdown
# Playbook: Resposta a Incidentes

## Severidades
| P1 | Sistema fora do ar, receita impactada | Resposta: 15min |
| P2 | Degradação, funcionalidade parcial    | Resposta: 1h    |
| P3 | Bug em produção, workaround existe    | Resposta: 4h    |

## Papéis
- **Incident Commander (IC)**: coordena, toma decisões
- **Investigador**: diagnostica a causa
- **Comunicador**: atualiza stakeholders

## Fluxo P1
1. Alerta dispara → IC assume → cria canal #inc-YYYY-MM-DD
2. IC designa Investigador e Comunicador
3. Investigador segue runbook de diagnóstico
4. Se > 30min sem resolução: escalar para nível 2
5. Resolução → Comunicador notifica → IC agenda postmortem em 48h

## Critérios de escalação
- Não encontrou a causa em 30min → chamar dev do serviço
- Mais de 1 serviço afetado → chamar arquiteto de plantão
- Dado comprometido → chamar segurança + jurídico
```

### Onde guardar
```
docs/playbooks/
  incident-response.md
  release-process.md
  onboarding-app.md
  disaster-recovery.md
```

---

## Postmortem — Análise Pós-Incidente

### O que é
Documento que analisa um incidente **após a resolução**: o que aconteceu,
por que aconteceu, timeline, impacto e — o mais importante — **ações para
que não aconteça de novo**.

### Princípio fundamental
**Blameless** (sem culpados). O postmortem investiga o **sistema**, não as
pessoas. "Por que o sistema permitiu que isso acontecesse?" em vez de
"Quem fez isso?".

### Quando usar
- Incidente P1/P2 em produção (obrigatório)
- Quase-incidente que só não virou P1 por sorte
- Problema que se repete (terceira vez = postmortem obrigatório)
- Qualquer evento onde o time quer aprender

### Quando NÃO usar
- Bug corrigido sem impacto em produção
- Problema já coberto por postmortem anterior (atualize o existente)

### Estrutura típica
```markdown
# Postmortem: API fora do ar por 47 minutos

## Resumo
Em 2026-06-10 entre 14:23 e 15:10 UTC, a API ficou indisponível.
Causa: deploy com migration que lockou tabela de 50M de registros.
Impacto: 100% dos requests falharam, ~2.300 usuários afetados.

## Timeline (UTC)
| 14:20 | Deploy v2.3.1 iniciado |
| 14:23 | Alertas de latência dispararam |
| 14:25 | IC assume, cria canal #inc-2026-06-10 |
| 14:30 | Investigador identifica lock na tabela users |
| 14:35 | Decisão: matar a migration + rollback do deploy |
| 14:45 | Rollback completo, migration cancelada |
| 15:00 | Lock liberado, requests voltando ao normal |
| 15:10 | Métricas confirmam recuperação total |

## Causa raiz
Migration `ALTER TABLE users ADD COLUMN` sem `CONCURRENTLY` travou a
tabela durante a adição do índice em 50M de registros.

## O que deu certo
- Alertas dispararam em < 3 minutos
- IC assumiu rapidamente, comunicação foi clara
- Runbook de rollback ECS funcionou

## O que deu errado
- Migration não foi testada com volume real (apenas 100 registros em staging)
- Sem gate de review para migrations em tabelas grandes
- Deploy e migration acoplados (deploy = migration automática)

## Ações (com dono e prazo)
| # | Ação | Dono | Prazo |
|---|---|---|---|
| 1 | Separar deploy de migration (ADR) | @fulano | 2026-06-20 |
| 2 | Gate obrigatório para migrations em tabelas > 1M rows | @ciclano | 2026-06-25 |
| 3 | Teste de migration com dump de produção em staging | @beltrano | 2026-07-01 |
| 4 | Runbook: "como cancelar migration presa" | @fulano | 2026-06-18 |

## Métricas de impacto
- Duração: 47 minutos
- Requests falhados: ~138.000
- Usuários afetados: ~2.300
- SLA impacto: -0.03% no mês
```

### Onde guardar
```
docs/postmortems/
  2026-06-10-api-fora-do-ar.md
  2026-05-22-deploy-quebrou-staging.md
```

### Regras de ouro
1. **Escreva em até 48h** — memória é fresca
2. **Blameless** — "o sistema permitiu" > "fulano errou"
3. **Ações com dono e prazo** — sem isso é só texto
4. **Review em grupo** — o time inteiro aprende, não só quem participou
5. **Linke com os artefatos** — ADR gerado, runbook criado, alert adicionado

---

## Resumo: quando usar cada um

| Pergunta | Documento |
|---|---|
| "O que vamos fazer e por quê?" | **ADR** |
| "Como faço X passo a passo?" | **Runbook** |
| "Qual o processo quando Y acontece?" | **Playbook** |
| "O que deu errado e como evitar?" | **Postmortem** |

```
Decisão técnica  ──→  ADR
                         │
                         ▼ gera necessidade de
Procedimento     ──→  Runbook
                         │
                         ▼ faz parte de um
Processo/cenário ──→  Playbook
                         │
                         ▼ quando falha, gera
Análise          ──→  Postmortem
                         │
                         ▼ gera ações que viram
                       ADRs, Runbooks, melhorias no Playbook
                       (ciclo fecha)
```
