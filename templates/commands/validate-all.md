---
description: Rodar todas as validações aplicáveis nos arquivos modificados (pré-PR)
---

Você vai validar os arquivos modificados antes de um PR. Siga os passos:

1. Execute `git status --short` e `git diff --name-only HEAD` para
   listar os arquivos modificados/novos.
2. Classifique cada arquivo por tipo:
   - `*.tf` → Terraform
   - `*.yaml`/`*.yml` em diretórios de manifests → Kubernetes
   - `Dockerfile*` → Docker
   - `*.sh` → Shell
   - `azure-pipelines*.yml` ou `pipelines/*.yml` → Pipeline
3. Para cada tipo presente, rode SOMENTE as validações daquele tipo.
   Se a skill correspondente tiver `scripts/validate.sh`, USE O SCRIPT
   em vez de rodar comandos individuais:
   - Terraform: `.opencode/skills/terraform-aws/scripts/validate.sh`
     (fallback: terraform fmt -check, terraform validate, tflint, checkov)
   - Kubernetes: `.opencode/skills/k8s-manifest-gitops/scripts/validate.sh <dir>`
     (fallback: kube-linter lint, kubectl diff -f)
   - Docker: `hadolint <arquivo>`
   - Shell: `shellcheck <arquivo>`
4. Se alguma ferramenta não estiver instalada, registre como AVISO e
   continue com as demais — não invente o resultado.
5. Reporte no formato:

```
# Validação pré-PR
## Arquivos analisados: N
## ✅ Passou: ...
## ⚠️ Avisos: ...
## ❌ Falhou: ... (com output do erro)
## Veredito: pronto pra PR? Sim/Não
```

NÃO corrija nada automaticamente. Só reporte.
