---
name: azure-pipelines-oidc
description: >
  Configurar autenticação OIDC de Azure Pipelines para AWS, incluindo
  role chaining. Invocar ao criar/alterar pipelines que acessam AWS.
---

# Azure Pipelines → AWS via OIDC

## Por que OIDC

Sem access keys long-lived: a pipeline troca um token OIDC do Azure
DevOps por credenciais temporárias STS. Nada pra vazar, nada pra rotacionar.

## A REGRA que evita horas de debug

Depois de um `aws sts assume-role` (role chaining), as credenciais
vivem em variáveis de ambiente. **Tasks `AWSCLI@1`/`AWSShellScript@1`
IGNORAM essas variáveis** — elas buscam credenciais da Service
Connection de novo, desfazendo o chain.

✅ Após o chain, use SEMPRE `bash` com `env:` explícito:

```yaml
- bash: |
    aws s3 sync ./dist "s3://$(bucketName)" --delete
  displayName: Deploy para S3
  env:
    AWS_ACCESS_KEY_ID: $(AWS_ACCESS_KEY_ID)
    AWS_SECRET_ACCESS_KEY: $(AWS_SECRET_ACCESS_KEY)
    AWS_SESSION_TOKEN: $(AWS_SESSION_TOKEN)
    AWS_REGION: $(awsRegion)
```

❌ NUNCA depois do chain:
```yaml
- task: AWSCLI@1   # vai re-autenticar com a Service Connection
```

## Padrão de step de login (template)

Use `templates/aws-login-oidc-step.yaml` desta skill como base.
Fluxo: federação OIDC → assume role de entrada → (opcional) assume
role do workload → exporta as 3 variáveis pro restante do job.

## Outras pegadinhas

- **`Rerun failed jobs` NÃO recarrega templates atualizados** — após
  editar um template, use `Run new`
- Variáveis exportadas entre steps: `echo "##vso[task.setvariable variable=X;issecret=true]$VALOR"`
- Trust policy da role precisa do `sub` correto:
  `sc://<org>/<projeto>/<service-connection-name>`
- Sessão STS expira (default 1h) — jobs longos precisam de
  `--duration-seconds` maior (se a role permitir) ou re-login

## Checklist

- [ ] Zero access keys hardcoded ou em variable group
- [ ] Pós-chain só bash + env: explícito
- [ ] Trust policy com sub/aud corretos
- [ ] issecret=true nas variáveis exportadas
- [ ] Testado com `aws sts get-caller-identity` antes do deploy real
