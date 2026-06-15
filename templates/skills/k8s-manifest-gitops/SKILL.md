---
name: k8s-manifest-gitops
description: >
  Criar ou modificar manifests Kubernetes (Deployment, Service, Ingress,
  HPA, PDB, NetworkPolicy, ArgoCD Application) no fluxo GitOps.
  Invocar para qualquer mudança de workload em cluster Kubernetes.
---

# Kubernetes Manifests — GitOps

## Regra absoluta

Mudanças em workloads vão via **commit no repo de manifests** (ArgoCD
sincroniza). PROIBIDO `kubectl apply/patch/edit` direto em produção.
Permitido em produção: get, describe, logs, diff (read-only).

## Workflow OBRIGATÓRIO

### Passo 1 — Criar a partir do template (NÃO escrever YAML do zero)
Copie `./.opencode/skills/k8s-manifest-gitops/templates/deployment.yaml`
para o destino e substitua os placeholders:
- `__APP__` → nome do app (lowercase, kebab-case)
- `__NAMESPACE__` → namespace
- `__IMAGE__` → registry/imagem:TAG-EXATA (NUNCA :latest)
- `__PORT__` → porta real da app (confirme; .NET 8+ oficial = 8080)
- `__REPLICAS__` → número de réplicas
NÃO remova campos do template. Campo não aplicável → comente com #.

### Passo 2 — Validar
Execute: `./.opencode/skills/k8s-manifest-gitops/scripts/validate.sh <dir>`
- Esperado: "✓ Validação passou"
- Se falhar: PARE, corrija, revalide.

### Passo 3 — Diff contra o cluster
Execute: `kubectl diff -f <dir>` (exit 1 = há diferenças, é normal)
MOSTRE o diff ao usuário antes de qualquer commit.

### Passo 4 — Commit em branch + PR
git checkout -b feature/<descricao> && git add + commit + push.
NUNCA push direto na main. O merge dispara o sync do ArgoCD.

## Padrões inegociáveis (já estão no template — não remova)

- `resources.requests` E `limits` realistas (requests inflados quebram autoscaler)
- annotation `cluster-autoscaler.kubernetes.io/safe-to-evict: "true"`
- liveness + readiness probes com path REAL da app
- `securityContext`: runAsNonRoot, drop ALL capabilities, readOnlyRootFilesystem
- image com tag exata ou SHA
- labels `app.kubernetes.io/name|instance|component|managed-by`
- PDB se replicas > 1

## Exemplos

### ✅ resources corretos
```yaml
resources:
  requests: { cpu: 100m, memory: 256Mi }
  limits:   { cpu: 500m, memory: 512Mi }
```

### ❌ errado
```yaml
resources:
  limits: { cpu: 8000m, memory: 32Gi }   # inflado, sem requests
```

## Pegadinhas conhecidas

- Pod Pending eterno → requests maiores que o nó comporta
- Autoscaler não faz scale-down → falta safe-to-evict ou requests irreais
- `preferred` anti-affinity NÃO garante separação — use `required`
- .NET 8+ imagens oficiais escutam na 8080 (non-root); targetPort deve bater
