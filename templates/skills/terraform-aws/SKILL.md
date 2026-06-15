---
name: terraform-aws
description: >
  Criar ou modificar módulos Terraform para recursos AWS: S3, CloudFront,
  ECS, Route53, ACM, IAM, ALB, ECR, RDS. Invocar para qualquer mudança
  de infraestrutura AWS via Terraform.
---

# Terraform AWS

## Workflow OBRIGATÓRIO (siga na ordem, valide cada checkpoint)

### Passo 1 — Validação completa
Execute: `./.opencode/skills/terraform-aws/scripts/validate.sh <dir>`
- Esperado: termina com "✓ Todas validações passaram"
- Se falhar: PARE, mostre o erro, corrija, rode de novo. Não avance.

### Passo 2 — Plan
Execute: `terraform plan -out=tfplan -detailed-exitcode`
- Exit code 0 → sem mudanças. NÃO faça apply. Informe e pare.
- Exit code 2 → há mudanças. MOSTRE o plan completo ao usuário.
- Outro → erro. PARE e reporte.

### Passo 3 — Revisão humana
AGUARDE o usuário confirmar o plan. Destaque qualquer `destroy`
ou `replace` no resumo — esses exigem atenção redobrada.

### Passo 4 — Apply (somente após confirmação)
Execute: `terraform apply tfplan`

## Padrões (use os exemplos, não invente)

### Providers — pin com ~>
```hcl
terraform {
  required_version = "~> 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.40" }
  }
}
```
❌ NUNCA: `version = ">= 5.0"` ou sem version.

### Iteração
```hcl
# ✅ for_each com map/set
resource "aws_s3_bucket" "this" {
  for_each = var.buckets
  bucket   = each.key
}
```
❌ NUNCA `count = length(var.lista)` se a lista pode reordenar.
`count` só para condicional: `count = var.enabled ? 1 : 0`.

### Recursos críticos (S3 com dados, RDS, Aurora)
```hcl
lifecycle { prevent_destroy = true }
```

### IAM
- Policies via `data "aws_iam_policy_document"` — nunca inline JSON
- Least privilege: `Resource = "*"` exige justificativa no ADR

### S3 (todos obrigatórios)
- versioning habilitado
- server_side_encryption (mínimo AES256)
- public_access_block com tudo true
- ownership_controls BucketOwnerEnforced

### CloudFront
- viewer_protocol_policy: redirect-to-https ou https-only
- minimum_protocol_version: TLSv1.2_2021
- Origem S3 via OAC (Origin Access Control)

### Tags obrigatórias em tudo
Environment, System, ManagedBy ("terraform"), CostCenter.

## Checklist antes de PR

- [ ] scripts/validate.sh passou
- [ ] plan revisado, sem destroy não intencional
- [ ] Naming convention do projeto seguida
- [ ] Pin ~> nos providers
- [ ] prevent_destroy nos recursos críticos
- [ ] Tags presentes
- [ ] Sem secrets hardcoded
