# ADR-0001: Criar bucket S3 + CloudFront para frontend React

## Status

`Implemented | 2026-06-10`

## Contexto

A aplicação frontend (React SPA) está hospedada em uma VM com NGINX.
Problemas atuais:

- Latência alta para usuários fora da região principal
- Deploy manual via `scp` para a VM — sem rollback, sem versionamento
- Custo da VM é fixo independente do tráfego (ocioso 80% do tempo)
- Sem HTTPS automático — certificado renovado manualmente

A equipe quer migrar para uma solução serverless com CDN, deploy
automatizado e custo proporcional ao uso.

## Decisão

Usar **S3 + CloudFront** para servir o frontend React como site estático.

- Bucket S3 privado (sem website hosting público)
- CloudFront com OAC (Origin Access Control) apontando pro bucket
- Certificado ACM na região us-east-1 (obrigatório para CloudFront)
- Route 53 com alias record para o domínio `app.exemplo.com.br`
- Invalidação de cache via pipeline no deploy

## Alternativas Consideradas

### Alternativa A — Azure Static Web Apps

**Como funciona:** upload direto, CDN integrada, free tier generoso.

**Prós:**
- Setup mais simples
- Free tier cobre projetos pequenos

**Contras:**
- Infraestrutura principal está na AWS
- Misturar clouds aumenta complexidade operacional

**Motivo da rejeição:** manter tudo na mesma cloud simplifica IAM, billing e troubleshooting.

### Alternativa B — Amplify Hosting

**Como funciona:** deploy automatizado a partir de repo Git, CDN inclusa.

**Prós:**
- CI/CD embutido
- Preview environments automáticos

**Contras:**
- Menos controle sobre cache e headers
- Lock-in mais forte (difícil migrar depois)

**Motivo da rejeição:** time prefere controle explícito via Terraform sobre a infra.

### Alternativa C — Não fazer nada

A VM funciona, mas o custo fixo e o deploy manual vão se tornar
insustentáveis conforme a aplicação cresce.

## Consequências

### Positivas

- Custo reduzido ~70% (S3 + CloudFront vs VM 24/7)
- Latência reduzida globalmente via edge locations
- Deploy automatizado com rollback (versionamento S3)
- HTTPS automático via ACM (sem renovação manual)

### Negativas

- Invalidação de cache adiciona 1-2 minutos ao deploy
- Equipe precisa aprender CloudFront behaviors (learning curve)

### Riscos

- **Cache stale após deploy**: mitigado com invalidação `/*` no pipeline
- **Custo inesperado por tráfego alto**: configurar budget alert em $50/mês

## Análise NFR

### Custo (FinOps)

- Estimativa mensal: ~$5 (S3) + ~$15 (CloudFront) = **$20/mês**
- VM atual: $85/mês
- Economia: **~76%**

### Segurança

- Bucket privado — acesso apenas via CloudFront OAC
- HTTPS obrigatório (redirect HTTP → HTTPS)
- Headers de segurança via CloudFront response headers policy

### Rollback

- Reativar versão anterior do objeto S3 (versionamento habilitado)
- Invalidar cache do CloudFront
- Tempo estimado: < 5 minutos

### Observabilidade

- CloudFront access logs → S3 bucket separado
- Métricas CloudWatch: requests, error rate, bytes transferred
- Alerta se error rate > 5% por 5 minutos

---

## Implementation Guidelines

### Pré-requisitos

- [x] Conta AWS com acesso ao Terraform state
- [x] Domínio `exemplo.com.br` gerenciado no Route 53
- [x] Pipeline de CI já existente no Azure DevOps
- [x] AWS OIDC federation configurada para o pipeline

### Repos e arquivos afetados

| Repo | Arquivos | Tipo de mudança |
|---|---|---|
| `infra-terraform` | `modules/s3-cloudfront/*.tf` | criar |
| `infra-terraform` | `environments/prod/main.tf` | editar (adicionar módulo) |
| `frontend-app` | `azure-pipelines.yml` | editar (adicionar step de deploy) |

### Ordem de implementação

1. **Passo 1**: Criar módulo Terraform `s3-cloudfront`
   - `main.tf`: bucket S3 (privado, versionado) + CloudFront distribution + OAC
   - `variables.tf`: domain_name, acm_certificate_arn, route53_zone_id
   - `outputs.tf`: distribution_id, bucket_name, domain_name
   - Validação: `terraform plan` mostra apenas criação de recursos

2. **Passo 2**: Criar certificado ACM em us-east-1
   - Usar validação DNS via Route 53
   - Aguardar status `ISSUED` antes de prosseguir
   - Validação: `aws acm describe-certificate` retorna status ISSUED

3. **Passo 3**: Aplicar módulo no environment prod
   - `terraform apply` com aprovação manual
   - Validação: CloudFront distribution status `Deployed`

4. **Passo 4**: Adicionar step de deploy no pipeline
   - `aws s3 sync build/ s3://$BUCKET --delete`
   - `aws cloudfront create-invalidation --distribution-id $DIST --paths "/*"`
   - Validação: pipeline roda green, site acessível no domínio

### Critérios de aceite

- [x] `terraform plan` sem mudanças (idempotente)
- [x] `tflint` passa sem warnings
- [x] `checkov` sem high/critical
- [x] `curl -I https://app.exemplo.com.br` retorna 200 com headers de segurança
- [x] Deploy via pipeline funciona end-to-end
- [x] Rollback testado: versão anterior restaurada em < 5 min
