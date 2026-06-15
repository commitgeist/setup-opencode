# ADR-0002: Diagnosticar e resolver CrashLoopBackOff em pods da API

## Status

`Implemented | 2026-06-12`

## Contexto

Os pods do deployment `api-pagamentos` no namespace `producao` entraram
em `CrashLoopBackOff` após o deploy da versão `v2.4.1`.

Sintomas observados:

- Pods reiniciando a cada ~30 segundos
- Health check falhando no `/health` (connection refused)
- Logs mostrando `System.Net.Sockets.SocketException: Address already in use`
- Rollout automático do ArgoCD travado (sync stuck)
- Alerta disparado: "Pod restart count > 5 in 10 minutes"

Impacto: API de pagamentos fora do ar, afetando checkout de clientes.

## Decisão

O problema é a porta de escuta da aplicação .NET 8+.

A partir do .NET 8, imagens oficiais rodam como **non-root** e escutam na
porta **8080** por padrão (não mais 80). O deployment estava com
`containerPort: 80` e o `targetPort` do Service apontando para 80.

A correção consiste em:

1. Alterar `containerPort` para `8080` no deployment
2. Alterar `targetPort` do Service para `8080`
3. Ajustar probes para porta `8080`
4. Documentar essa pegadinha para evitar recorrência

## Alternativas Consideradas

### Alternativa A — Forçar porta 80 via variável de ambiente

**Como funciona:** Setar `ASPNETCORE_URLS=http://+:80` no container.

**Prós:**
- Não precisa mudar manifests Kubernetes

**Contras:**
- Roda contra o padrão da imagem oficial
- Conflito com non-root user (porta < 1024 precisa de root)
- Próximo upgrade da imagem pode quebrar de novo

**Motivo da rejeição:** vai contra o padrão non-root e é frágil.

### Alternativa B — Usar imagem com user root

**Como funciona:** Override do user no Dockerfile para rodar como root.

**Prós:**
- Porta 80 funciona direto

**Contras:**
- Violação de security best practice
- Pod Security Standards vão bloquear no futuro

**Motivo da rejeição:** risco de segurança inaceitável.

### Alternativa C — Não fazer nada

API está fora do ar. Não é opção.

## Consequências

### Positivas

- API volta ao ar em minutos (fix simples de manifests)
- Alinhamento com o padrão non-root do .NET 8+
- Documentação previne recorrência para outros serviços

### Negativas

- Todos os outros deployments .NET precisam ser auditados (dívida técnica)

### Riscos

- **Outros serviços com mesmo problema**: auditoria prioritária pós-incidente
- Probabilidade alta (8 outros serviços .NET no cluster)

## Análise NFR

### Custo (FinOps)

- Sem impacto — apenas mudança de configuração

### Segurança

- Melhora: alinhamento com non-root é mais seguro
- Sem exposição de novas portas ou mudança de network policy

### Rollback

- Se a correção falhar: `kubectl rollout undo deployment/api-pagamentos`
- Tempo: < 1 minuto
- Sem ponto de não-retorno

### Observabilidade

- Confirmar: pods healthy sem restart por 30 minutos
- Confirmar: métricas de request success rate voltam a 99.9%+
- Confirmar: alerta de restart resolvido automaticamente

### Blast Radius

- Fix isolado ao deployment `api-pagamentos`
- Demais serviços não são afetados pela mudança
- Auditoria dos outros serviços .NET deve ser feita separadamente

---

## Implementation Guidelines

### Pré-requisitos

- [x] Acesso ao repo de manifests GitOps
- [x] Confirmação via logs de que o erro é `Address already in use` na porta 80
- [x] `kubectl get pods -n producao` confirma CrashLoopBackOff

### Diagnóstico realizado

```bash
# 1. Verificar status dos pods
kubectl get pods -n producao -l app=api-pagamentos
# → CrashLoopBackOff, restarts: 12

# 2. Verificar logs
kubectl logs -n producao deployment/api-pagamentos --previous
# → System.Net.Sockets.SocketException: Address already in use
# → Now listening on: http://[::]:8080

# 3. Verificar porta configurada no deployment
kubectl get deployment api-pagamentos -n producao -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}'
# → 80  (ERRADO — .NET 8+ escuta em 8080)

# 4. Verificar service
kubectl get svc api-pagamentos -n producao -o jsonpath='{.spec.ports[0].targetPort}'
# → 80  (ERRADO — precisa ser 8080)
```

### Repos e arquivos afetados

| Repo | Arquivos | Tipo de mudança |
|---|---|---|
| `argocd-manifests` | `producao/api-pagamentos/deployment.yaml` | editar |
| `argocd-manifests` | `producao/api-pagamentos/service.yaml` | editar |

### Ordem de implementação

1. **Passo 1**: Corrigir `containerPort` e probes no deployment.yaml
   - `containerPort`: 80 → **8080**
   - `livenessProbe.httpGet.port`: 80 → **8080**
   - `readinessProbe.httpGet.port`: 80 → **8080**
   - `startupProbe.httpGet.port`: 80 → **8080**
   - Validação: `kubectl diff -f deployment.yaml` mostra apenas mudança de porta

2. **Passo 2**: Corrigir `targetPort` no service.yaml
   - `targetPort`: 80 → **8080**
   - Validação: `kubectl diff -f service.yaml` mostra apenas mudança de porta

3. **Passo 3**: Commit e push (GitOps)
   - ArgoCD detecta e sincroniza automaticamente
   - **NÃO** usar `kubectl apply` direto
   - Validação: ArgoCD app status `Synced` e `Healthy`

4. **Passo 4**: Confirmar recuperação
   - Pods sem restart por 10 minutos
   - Health check respondendo 200 na porta 8080
   - Requests chegando com sucesso no endpoint

### Critérios de aceite

- [x] Pods running sem restart por 30 minutos
- [x] `kubectl get pods -n producao -l app=api-pagamentos` → Running, 0 restarts
- [x] `curl` no endpoint retorna 200
- [x] Alerta de CrashLoopBackOff resolvido
- [x] Commit no repo GitOps (nunca kubectl apply direto)

### Post-mortem — ações preventivas

- [ ] Auditar todos os deployments .NET para `containerPort` vs porta real
- [ ] Adicionar no AGENTS.md: `.NET 8+ escuta na 8080 (non-root)`
- [ ] Adicionar check no kube-linter: `containerPort` deve ser >= 1024
