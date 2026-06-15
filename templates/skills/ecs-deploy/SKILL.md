---
name: ecs-deploy
description: >
  Criar ou modificar task definitions, services e deploy de aplicações
  em ECS Fargate. Invocar para qualquer trabalho de CI/CD ou
  infraestrutura envolvendo Amazon ECS.
---

# ECS Fargate — Deploy

## Conceitos em 30 segundos (mapa mental)

```
Cluster (agrupador lógico)
 └── Service (mantém N tasks rodando + liga no ALB)
      └── Task (instância rodando de uma...)
           └── Task Definition (receita: imagem, cpu/mem, env, ports)
ALB → Target Group → tasks registradas (health check decide o tráfego)
```

Deploy = registrar NOVA REVISION da task definition + apontar o
service pra ela. ECS faz rolling: sobe novas tasks, espera healthy,
drena as antigas.

## Workflow OBRIGATÓRIO para deploy

### Passo 1 — Task definition a partir do template
Copie `./.opencode/skills/ecs-deploy/templates/task-definition.json`
e substitua os placeholders:
- `__APP__`, `__IMAGE__` (tag exata), `__PORT__`
- `__CPU__` / `__MEMORY__` (combinações válidas Fargate:
  256/512, 256/1024, 512/1024, 512/2048, 1024/2048, 1024/3072...)
- `__EXEC_ROLE_ARN__` (pull de imagem + logs) e `__TASK_ROLE_ARN__`
  (permissões da APP em runtime — são roles DIFERENTES)
- `__REGION__`, `__LOG_GROUP__`
NUNCA invente ARNs — confirme com `aws iam get-role` ou pergunte.

### Passo 2 — Registrar revision
```bash
aws ecs register-task-definition \
  --cli-input-json file://task-definition.json
```
- Esperado: JSON de resposta com `"revision": N`
- Anote o N. Se erro de validação: PARE, mostre o erro.

### Passo 3 — Atualizar o service
```bash
aws ecs update-service \
  --cluster <cluster> --service <service> \
  --task-definition <familia>:<N>
```

### Passo 4 — Acompanhar o rollout
Execute: `./.opencode/skills/ecs-deploy/scripts/validate-service.sh <cluster> <service>`
- Esperado: "✓ Service estável" + targets healthy
- Se tasks ciclando (sobe e morre): ver Troubleshooting abaixo. PARE
  o diagnóstico em leitura — não tente "consertar" mudando configs
  às cegas.

## Regras

- **Env vars**: configuração não-sensível em `environment`;
  sensível em `secrets` com `valueFrom` (ARN do Secrets Manager/SSM).
  NUNCA secret em `environment`.
- **.NET nested config**: separador é `__` (ex: `ConnectionStrings__Default`)
- **Logs**: sempre `awslogs` driver; crie o log group ANTES do deploy
- **Nova revision, nunca editar a atual**: revisions são imutáveis
- **healthCheckGracePeriodSeconds** no service: dê tempo da app subir
  (60-120s para .NET) antes do ALB começar a contar falhas

## Troubleshooting (ordem de verificação)

1. Task morre imediatamente →
   `aws ecs describe-tasks --cluster X --tasks <arn>` → campo
   `stoppedReason` + `containers[].reason`
2. `CannotPullContainerError` → execution role sem permissão ECR,
   ou imagem/tag não existe, ou task sem rota pra internet/VPC endpoint
3. Task sobe mas ALB mata → health check path/porta errados, ou
   grace period curto demais
4. `ResourceInitializationError ... secrets` → execution role sem
   `secretsmanager:GetSecretValue` no ARN do secret
5. App não conecta no banco → security group da task não libera
   egress, ou SG do banco não libera ingress da task

## Checklist antes de PR/deploy

- [ ] Sem placeholders __XXX__ no JSON
- [ ] Imagem com tag exata (nunca :latest)
- [ ] CPU/memory é combinação Fargate válida
- [ ] Secrets via valueFrom, não environment
- [ ] Log group existe
- [ ] Health check path confirmado com o dev (não chutado)
- [ ] Roles: execution ≠ task, ambas confirmadas
