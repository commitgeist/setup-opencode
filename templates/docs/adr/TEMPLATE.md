# ADR-NNNN: Título da decisão

## Status

`Proposed | YYYY-MM-DD`

> Status válidos: Proposed, Approved, Implemented, Superseded, Archived
> Ao mudar status, manter data: `Implemented | 2026-06-15`

## Contexto

Descreva o problema, o cenário atual e as forças que motivam essa decisão.

- Qual o estado atual?
- O que está incomodando ou precisa ser resolvido?
- Quais constraints existem (negócio, técnicas, regulatórias)?
- Quais sistemas/recursos são afetados?

## Decisão

Decisão escolhida, em uma ou duas frases diretas.

Detalhamento técnico em seguida:
- O que será feito
- Quais recursos serão criados/modificados/destruídos
- Quais tecnologias/serviços serão usados

## Alternativas Consideradas

### Alternativa A — <nome>

**Como funciona:** breve descrição.

**Prós:**
- ...

**Contras:**
- ...

**Motivo da rejeição:** ...

### Alternativa B — <nome>

(repetir estrutura)

### Alternativa C — Não fazer nada

Sempre considere. Por que mudar é melhor que manter como está?

## Consequências

### Positivas

- Ganhos esperados (performance, custo, segurança, manutenibilidade)

### Negativas

- Trade-offs aceitos
- Limitações introduzidas

### Riscos

- O que pode dar errado
- Probabilidade × impacto
- Plano de mitigação

## Análise NFR (Non-Functional Requirements)

### Custo (FinOps)

- Estimativa mensal: $X
- Comparação com solução atual: +/-Y%
- Reserved/spot opportunities

### Segurança

- Modelo de auth (OIDC, IAM, RBAC)
- Secrets management
- Network exposure
- Compliance impacts (LGPD, ISO, etc.)

### Rollback

- Como reverter caso algo dê errado
- Tempo estimado de rollback
- Pontos de não-retorno (se houver)

### Observabilidade

- Métricas a serem coletadas
- Logs estruturados
- Traces (se aplicável)
- Alertas críticos

### Blast Radius

- O que quebra se essa mudança falhar?
- Quantos clientes/serviços são afetados?
- Janela de manutenção necessária?

---

## Implementation Guidelines

> **Contrato para o DevOps Engineer Agent.**
> Esta seção deve ser machine-readable e executável passo a passo.

### Pré-requisitos

- [ ] Recursos pré-existentes (verificar antes de começar)
- [ ] Variáveis/secrets configurados em Key Vault / Variable Groups
- [ ] Acessos necessários (roles, permissions)
- [ ] PRs pendentes que bloqueiam esta implementação

### Repos e arquivos afetados

| Repo | Arquivos | Tipo de mudança |
|---|---|---|
| `Infrastructure/terraform-aws` | `modules/cloudfront/*.tf` | criar |
| `argocd-manifests-production` | `apps/myapp/values.yaml` | editar |

### Ordem de implementação

1. **Passo 1**: descrição clara da ação
   - Comando ou arquivo a modificar
   - Validação: `terraform plan` mostra apenas adição
2. **Passo 2**: ...
3. **Passo 3**: ...

> ⚠️ Não pular passos. Não fazer fora de ordem.

### Critérios de aceite

A implementação está completa quando TODOS os itens abaixo passam:

- [ ] `terraform plan` sem mudanças (idempotente)
- [ ] `tflint` passa sem warnings
- [ ] `checkov` sem high/critical
- [ ] Recurso responde no endpoint esperado
- [ ] Métricas chegando no Prometheus
- [ ] Health check verde por 5 minutos consecutivos
- [ ] Documentação atualizada (Wiki / README)

### Comandos de validação

```bash
# Validação 1: <descrição>
<comando>

# Validação 2: <descrição>
<comando>
```

### Plano de rollback

Se algo der errado na implementação:

1. **Detecção**: como saber que deu errado (alerta, métrica, sintoma)
2. **Ação imediata**: comando ou step pra parar o sangramento
3. **Reversão**:
   ```bash
   <comandos para reverter>
   ```
4. **Validação pós-rollback**: como confirmar que voltou ao estado anterior

---

## Notas de implementação

> Preenchido pelo DevOps Engineer ao concluir.

- **Data de implementação**: YYYY-MM-DD
- **Desvios do plano**: nenhum / lista detalhada
- **Pendências**: ...
- **Lições aprendidas**: ...
