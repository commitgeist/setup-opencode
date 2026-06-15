# Curso OpenCode para DevOps

> Material de referência consolidado para uso do OpenCode em fluxos DevOps/SRE.
> Foco 80% DevOps, 20% Dev — Terraform, Kubernetes, Docker, AWS, Azure, CI/CD.

## Sumário

- [M0 — Setup mínimo](#m0--setup-mínimo)
- [M1 — Modelo mental: como o OpenCode pensa](#m1--modelo-mental)
- [M2 — Modelos e provedores: o que é confiável](#m2--modelos-e-provedores)
- [M3 — Hierarquia de configuração](#m3--hierarquia-de-configuração)
- [M4 — Agents e Subagents: invocação automática, manual e paralelismo](#m4--agents-e-subagents-aprofundamento)
- [M5 — Skills para DevOps](#m5--skills-para-devops)
- [M6 — MCPs no teu stack](#m6--mcps-no-teu-stack)
- [M7 — Segurança e permissions](#m7--segurança-e-permissions)
- [M8 — Receitas por tecnologia](#m8--receitas-por-tecnologia)
- [M9 — Anti-patterns e armadilhas](#m9--anti-patterns-e-armadilhas)
- [M10 — Roteiro de adoção (4 semanas)](#m10--roteiro-de-adoção-4-semanas)
- [TL;DR](#tldr-cola-pra-parede)

---

## M0 — Setup mínimo

```bash
# Instalação
curl -fsSL https://opencode.ai/install | bash
# ou: npm install -g opencode

# Estrutura recomendada num repo
mkdir -p .opencode/{agents,skills,commands}
touch AGENTS.md opencode.json
```

Estrutura de arquivos do OpenCode:

```
~/.config/opencode/        # GLOBAL (vale pra todos os repos)
  opencode.json
  AGENTS.md
  agents/<nome>.md
  skills/<nome>/SKILL.md
  commands/<nome>.md

<repo>/.opencode/          # PROJETO (só esse repo)
  opencode.json            # sobrescreve o global
  agents/
  skills/
  commands/
<repo>/AGENTS.md           # rules específicas do repo
```

A precedência (mais específico sobrescreve): Remote `.well-known/opencode` < Global < Custom < Project.

---

## M1 — Modelo mental

Três coisas que mudam tudo se você entender:

### 1. Plan Mode vs Build Mode (Tab alterna)

- **Plan**: o agente lê, propõe, mostra diff — não escreve nem executa bash.
- **Build**: o agente faz.

Hábito: **sempre planeje em Plan, só passe pra Build quando o plano estiver claro**. Pra infra, isso é a diferença entre um `terraform apply` certo e um pesadelo.

### 2. LSP feedback loop (diferencial vs cursor/copilot)

O OpenCode integra com Language Servers — TypeScript, Python (Pyright), Go (gopls), Rust, Java e 18+ — e o agente recebe diagnósticos do compilador em tempo real durante a task. Isso permite autocorreção antes mesmo do agente reportar.

Pra DevOps isso ajuda em código (Python helpers, IaC TypeScript com CDK). Pra YAML/HCL puro o ganho é menor — daí a importância das skills (M5) e validações em bash (M8).

### 3. Tudo é arquivo, tudo é Git

Agents, skills, AGENTS.md, opencode.json — tudo markdown ou JSON. Versiona no repo. Quando alguém entra no time, faz `git clone` e já tem o setup.

---

## M2 — Modelos e provedores

**A pergunta direta: free é confiável?** Resposta curta: depende do que "confiável" significa.

### Três eixos de confiança

| Eixo | O que avaliar |
|---|---|
| **Qualidade do output** | O modelo gera Terraform/K8s sem alucinar? |
| **Privacidade** | Teus prompts viram treino de outro modelo? |
| **Disponibilidade** | Vai estar lá amanhã? Rate limit aceitável? |

### OpenCode Zen (a opção curada)

O Zen é um conjunto curado de modelos e provedores que a equipe do OpenCode testou e benchmarkou. Os provedores seguem política de retenção zero e não usam seus dados para treino — com exceções:

- **Big Pickle** e **North Mini Code Free** usam dados coletados pra melhorar o modelo durante o período free
- **Nemotron 3 Ultra Free** é "trial use only — não submeta dados pessoais ou confidenciais"
- **OpenAI** e **Anthropic** retêm requests por 30 dias conforme política deles

**Tradução pro contexto corporativo / código de cliente:**

- ✅ **Pode usar com tranquilidade**: Claude (Anthropic), GPT (OpenAI) via Zen — retenção 30 dias, sem treino.
- ⚠️ **Cuidado**: Big Pickle, North Mini Code, Nemotron Free — dados podem virar treino.
- ❌ **Nunca em código sensível de cliente**: qualquer modelo "free" sem zero-retention explícito.

### OpenRouter

Com OpenRouter você nunca tem certeza se está pegando a melhor versão do modelo, porque cada provedor configura diferente. É bom pra experimentar, mas pra produção prefira ir direto no provedor (Anthropic, OpenAI) ou via Zen.

### Local com Ollama/LM Studio

A única opção 100% privada. O fluxo agêntico inteiro roda local, nenhuma chamada de API sai da máquina. Pra DevOps em código sensível é a opção mais defensável.

Trade-off: hardware (modelo decente pede 32GB+ RAM, GPU ajuda muito), e qualidade abaixo dos frontier models.

⚠️ Mesmo rodando local, prompts ainda são enviados à cloud do OpenCode pra gerar títulos de sessão — é uma pegadinha de privacidade conhecida. Se isso é dealbreaker, segue o issue #16117.

### Recomendação prática (mix 80/20 DevOps/Dev)

```json
{
  "agent": {
    "architect": { "model": "anthropic/claude-opus-4-5" },
    "devops-engineer": { "model": "anthropic/claude-sonnet-4-6" },
    "reviewer": { "model": "anthropic/claude-haiku-4-5" }
  }
}
```

- Pra estudos pessoais / não-cliente: Zen com Kimi/MiniMax free funciona.
- Pra qualquer coisa de cliente em produção: paga direto Anthropic/OpenAI.

---

## M3 — Hierarquia de configuração

Existem **quatro lugares** onde você instrui o OpenCode:

### 1. `opencode.json` — Como o OpenCode roda

Define **agents, modelos, MCPs, permissões padrão**. É o "infra-as-code" do OpenCode.

### 2. `AGENTS.md` — Como o **projeto** funciona

Convenções do código/repo. Vai no contexto de **toda** sessão. Rode `/init` no diretório do projeto pra gerar — ele escaneia os arquivos importantes, faz perguntas-alvo quando o código não responde, e cria um AGENTS.md conciso. Comite no Git.

### 3. `agents/<nome>.md` — Quem cada agente é

System prompt + permissões específicas (vide M4).

### 4. `skills/<nome>/SKILL.md` — Workflow recorrente

Receita pra uma tarefa específica que o agente carrega **só quando precisa** (vide M5).

### Regra de bolso pra decidir onde escrever

| Conhecimento | Vai em |
|---|---|
| "Nesse repo, manifests vão em `argocd-manifests-production/`" | `AGENTS.md` |
| "O agente Architect só pode escrever em `docs/adr/`" | `agents/architect.md` |
| "Pra liberar um release, o processo é X→Y→Z" | `skills/release/SKILL.md` |
| "Use o MCP do Azure DevOps com domínios pipelines+repos" | `opencode.json` |

---

## M4 — Agents e Subagents (aprofundamento)

### A taxonomia

Dois tipos:
- **Primary agents** — você interage diretamente, alterna com Tab. Build e Plan são built-in.
- **Subagents** — especialistas que primários invocam pra tasks específicas, ou você chama manualmente com `@`. Vêm três built-in: General, Explore e Scout.

```
┌─────────────────────────────────────────────┐
│  VOCÊ (humano)                              │
│    │                                         │
│    │ Tab alterna                             │
│    ▼                                         │
│  PRIMARY AGENT  (build / plan / architect)  │
│    │                                         │
│    │ Task tool ou @mention                   │
│    ▼                                         │
│  SUBAGENT  (explore / reviewer / scanner)   │
│    │                                         │
│    │ (por padrão NÃO pode chamar outro)      │
│    ▼                                         │
│  [bloqueado sem task_budget]                 │
└─────────────────────────────────────────────┘
```

### Invocação automática vs manual

Subagents podem ser invocados pelo primary como um Task tool call ou diretamente pelo usuário via `@` mention. A description do subagent é a lista que o primary lê — sua execute function abre uma nova sessão, dá as tools e system prompt corretos, e roda independente.

**O segredo da invocação automática:** o primary só chama um subagent se a `description` dele bater com o que o usuário pediu. Description ruim → o agente nunca é chamado.

**Description boa:**

```yaml
description: >
  Valida manifests Kubernetes contra políticas do cluster.
  Invocar quando o usuário pedir review/audit de YAML, manifests,
  Helm charts, ou após qualquer mudança em argocd-manifests-*.
  Sempre antes de commits que tocam workloads.
```

**Description ruim:**

```yaml
description: "K8s helper"   # genérico, nunca dispara
```

### Paralelismo — três padrões

#### Padrão A — Sessões paralelas (manual, mais usado)

Abre múltiplas instâncias do `opencode` em terminais diferentes. Pra evitar conflito de arquivos, use **git worktrees**:

```bash
# Tarefa 1: migração Alloy
git worktree add ../infra-alloy feature/promtail-to-alloy

# terminal 1
cd <repo-principal> && opencode

# terminal 2 (paralela, isolada)
cd ../infra-alloy && opencode
```

Cada uma vê o seu próprio working tree. Zero conflito.

#### Padrão B — Múltiplos subagents disparados pelo primary

Você pede explicitamente paralelismo:

```
> Em paralelo:
  1) @explore mapeia todos os usos de AWSCLI@1 nos templates de pipeline
  2) @security-reviewer audita aws-login-oidc.yaml
  3) @explore lista todos os manifests com kind: Deployment sem resources.requests
  Depois consolide os três relatórios.
```

O primary dispara três Task calls, cada um abre uma sessão filha. Você navega entre elas:

- `<Leader>+Down` — entra na primeira sessão filha
- Dentro da filha: `Right`/`Left` ciclam entre filhas
- `Up` — volta à conversa principal

Permite ir do macro (sessão pai) ao detalhe (filhas) sem perder contexto.

#### Padrão C — Pipeline de papéis (handoff sequencial)

Architect → Engineer → Reviewer, com **arquivos** sendo a fronteira:

```
1. Architect (Tab) escreve docs/adr/0007.md
2. VOCÊ revisa o ADR
3. DevOps Engineer (Tab) lê o ADR e implementa
4. Reviewer (@reviewer) valida contra o ADR
5. Você abre o PR
```

A vantagem do "arquivo como handoff": o estado fica versionado, revisável, não depende da sessão estar viva.

### Subagent → Subagent (avançado)

Por padrão subagent não pode invocar subagent. Pra liberar, defina `task_budget` no opencode.json e permissions no task tool. Sem isso, você protege de loops infinitos.

Habilite só se tiver caso claro. Pra DevOps quase nunca precisa.

### Exemplo completo de `opencode.json` com 3 agents

```json
{
  "$schema": "https://opencode.ai/config.json",
  "default_agent": "architect",
  "agent": {
    "architect": {
      "description": "Planeja mudanças de infra e gera ADRs em docs/adr/",
      "mode": "primary",
      "model": "anthropic/claude-opus-4-5",
      "temperature": 0.3,
      "tools": { "write": true, "edit": true, "bash": false },
      "permission": {
        "write": { "docs/adr/*": "allow", "*": "deny" },
        "edit":  { "docs/adr/*": "allow", "*": "deny" },
        "bash": "deny"
      }
    },
    "devops-engineer": {
      "description": "Implementa ADRs aprovados de docs/adr/",
      "mode": "primary",
      "model": "anthropic/claude-sonnet-4-6",
      "temperature": 0.2,
      "tools": { "write": true, "edit": true, "bash": true },
      "permission": {
        "bash": {
          "terraform apply*": "ask",
          "kubectl apply*": "ask",
          "kubectl delete*": "deny",
          "kubectl patch*": "deny",
          "git push*": "ask",
          "*": "allow"
        }
      }
    },
    "reviewer": {
      "description": "Valida implementação contra o ADR. Read-only. Invocar com @reviewer após implementar.",
      "mode": "subagent",
      "model": "anthropic/claude-haiku-4-5",
      "tools": { "write": false, "edit": false, "bash": true },
      "permission": {
        "bash": {
          "terraform plan*": "allow",
          "kubectl get*": "allow",
          "kubectl diff*": "allow",
          "*": "deny"
        }
      }
    }
  }
}
```

---

## M5 — Skills para DevOps

### O que é uma skill, mecanicamente

Uma pasta por skill com um `SKILL.md` dentro. O OpenCode procura em `.opencode/skills/*/SKILL.md` no projeto, e globalmente em `~/.config/opencode/skills/*/SKILL.md`. O frontmatter YAML deve ter os campos reconhecidos; campos desconhecidos são ignorados.

A skill é **carregada sob demanda** (não fica sempre no contexto como o AGENTS.md). O agente lê a description e decide se chama.

### Anatomia mínima

```
.opencode/skills/
  terraform-azure-aks/
    SKILL.md              # frontmatter + instruções
    references/
      naming-convention.md
    templates/
      aks-cluster.tf
    scripts/
      validate.sh
```

Exemplo de `SKILL.md`:

````markdown
---
name: terraform-azure-aks
description: >
  Criar ou modificar módulos Terraform de cluster AKS.
  Invocar quando o usuário pedir pra criar/alterar AKS, nodepool, ou
  qualquer recurso Microsoft.ContainerService/managedClusters.
---

# Terraform AKS

## Quando usar
- Novo cluster AKS
- Adicionar/remover nodepool
- Mudança em autoscaler, taints, tolerations

## Workflow obrigatório
1. Ler `references/naming-convention.md`
2. Usar `templates/aks-cluster.tf` como ponto de partida
3. Rodar `scripts/validate.sh` antes de propor mudança
4. Sempre `terraform plan -out=tfplan` e mostrar antes de qualquer apply

## Naming
prc + env(p|i|d) + sistema + region(zu1|zu2) + "aks" + 3-dig-seq
Exemplo: myorgp1zu1aks001

## Padrões que NUNCA esquecer
- system_node_pool com taint CriticalAddonsOnly=true:NoSchedule
- user_node_pool com `tags = { nodepool_purpose = "..." }`
- diagnostics: enviar pra log_analytics_workspace_id existente
- network_profile.network_plugin = "azure", network_policy = "calico"

## Checklist antes de PR
- [ ] terraform fmt
- [ ] terraform validate
- [ ] terraform plan limpo (sem destroy não-intencional)
- [ ] tflint passa
- [ ] checkov sem high/critical
````

### Como criar skills sem dor

**Método manual** — escreva você mesmo. Bom pras primeiras.

**Método assistido** — o `opencode-skill-creator` é um plugin que entrevista você (3-5 perguntas), gera um draft em `/tmp/opencode-skills/<nome>/`, e depois você instala no projeto ou global. A description é o gatilho principal — ela é o que decide se a skill é invocada.

```bash
# Instala o skill-creator
opencode plugin add @opencode/skill-creator

# No TUI
> Crie uma skill pra deploy de cluster AKS no padrão da empresa
# → ele entrevista, gera draft, você revisa e instala
```

### Skills úteis pro stack DevOps

Sugiro começar com estas 8:

| Skill | Quando dispara |
|---|---|
| `terraform-aws` | Pedidos de S3/CloudFront/ECS/Route53 |
| `terraform-azure-aks` | Pedidos de AKS, nodepool, autoscaler |
| `azure-pipelines-oidc` | Criar pipeline com auth AWS via OIDC |
| `k8s-manifest-gitops` | Editar manifests dos repos argocd-manifests-* |
| `dockerfile-hardening` | Criar/auditar Dockerfile |
| `argocd-application` | Criar/modificar Application/AppSet do ArgoCD |
| `helm-values` | Customizar values.yaml mantendo upstream limpo |
| `pre-commit-iac` | Rodar tflint, checkov, kube-linter, hadolint, trivy |

Cada uma encapsula o "como vocês fazem aqui" — naming, OIDC, GitOps, pin de versão. Sem skill, o agente improvisa. Com skill, segue o padrão.

---

## M6 — MCPs no teu stack

MCP = como o OpenCode "vê" sistemas externos. Cada MCP server expõe tools.

### Configuração no `opencode.json`

```json
{
  "mcp": {
    "azure-devops": {
      "type": "local",
      "command": ["npx", "-y", "@azure-devops/mcp", "minha-org", "-d", "pipelines", "repositories", "work-items"],
      "enabled": true
    },
    "aws": {
      "type": "local",
      "command": ["uvx", "awslabs.aws-api-mcp-server@latest"],
      "environment": { "AWS_REGION": "us-east-1" },
      "enabled": true
    },
    "terraform": {
      "type": "local",
      "command": ["docker", "run", "-i", "--rm", "hashicorp/terraform-mcp-server"],
      "enabled": true
    },
    "kubernetes": {
      "type": "local",
      "command": ["npx", "-y", "kubernetes-mcp-server@latest"],
      "enabled": true
    }
  }
}
```

### Dicas críticas de MCP

1. **Domain filtering reduz contexto**. No Azure DevOps MCP, use `-d` pra limitar domínios carregados. Domínios disponíveis: `core`, `work`, `work-items`, `repositories`, `wiki`, `pipelines`, `search`, `test-plans`, `advanced-security`. Carregar tudo enche o contexto e o agente fica confuso.

2. **Read-only primeiro**. Ao adotar um novo MCP, sempre comece com permissões read-only e escope acesso cuidadosamente antes de dar write access em produção.

3. **Per-agent enabling**. Você pode desabilitar MCPs por agente no frontmatter pra evitar que o Architect tenha acesso a write tools.

4. **Auth**. Azure DevOps MCP faz login via browser na primeira chamada (não persiste secret em arquivo — bom). AWS MCP usa as credenciais do shell (`AWS_PROFILE`).

### MCPs mais relevantes pro mundo DevOps

- **GitHub MCP** — busca código, cria/atualiza issues, abre PRs e comenta, dispara workflows
- **Snyk MCP** — escaneia código, configs e dependências
- **Wiz MCP** — traz contexto de CSPM pro workflow

Ordem de impacto típica pra DevOps: **Azure DevOps > AWS > Kubernetes > Terraform > GitHub > Snyk/Trivy**.

---

## M7 — Segurança e permissions

### O insight mais importante

**No OpenCode, guardrail de verdade é `permission`, não system prompt.**

Escrever "você nunca faz X" no prompt **ajuda**, mas é o `permission` que **garante**.

### Sintaxe completa

```yaml
tools:
  write: true | false            # macro: allow all / deny all
  edit:  true | false
  bash:  true | false

permission:
  write:
    "docs/adr/*": allow
    "infra/**": ask
    "*": deny
  edit:
    "*.tf": ask
    "*": allow
  bash:
    "terraform plan*": allow
    "terraform apply*": ask        # pede confirmação humana
    "kubectl apply*": ask
    "kubectl delete*": deny
    "kubectl patch*": deny
    "rm -rf*": deny
    "git push*": ask
    "*": allow
```

Três níveis: `allow`, `ask`, `deny`. Glob simples. **A regra mais específica ganha.**

### Receitas de permission por papel

**Architect (planejador)**

```yaml
tools: { write: true, edit: true, bash: false }
permission:
  write: { "docs/adr/*": allow, "*": deny }
  edit:  { "docs/adr/*": allow, "*": deny }
  bash: deny
```

**DevOps Engineer (executor)**

```yaml
tools: { write: true, edit: true, bash: true }
permission:
  bash:
    "terraform apply*": ask
    "kubectl apply*": ask
    "kubectl delete*": deny
    "kubectl patch*": deny
    "*aws s3 rb*": deny
    "*aws ec2 terminate*": ask
    "az * delete*": ask
    "git push origin main": deny
    "git push origin master": deny
    "git push*": ask
    "*": allow
```

**Reviewer (read-only)**

```yaml
tools: { write: false, edit: false, bash: true }
permission:
  bash:
    "*plan": allow
    "*get*": allow
    "*describe*": allow
    "*diff*": allow
    "*": deny
```

### Política de secrets

Regra única: **nunca confie no agente com secrets**.

- Variáveis sensíveis: Key Vault / variable groups do Azure DevOps
- No `.opencode/` nunca commite chaves. Use `.env` e mantém no `.gitignore`
- Pra MCPs que precisam de token: passe via `environment` no `opencode.json` referenciando variáveis do ambiente, nunca hardcode

### Sandbox de execução

Pra tarefas arriscadas, rode o OpenCode dentro de um container. Aí mesmo um `rm -rf /` autorizado por engano não pega o host:

```bash
docker run -it --rm \
  -v $(pwd):/work \
  -v ~/.config/opencode:/root/.config/opencode \
  -w /work \
  opencode/opencode:latest
```

---

## M8 — Receitas por tecnologia

### Terraform

**Padrões que o agente sempre erra sem skill:**

- Versões soltas (`>= 5.0` em vez de `~> 5.40`)
- Esquece `lifecycle { prevent_destroy = true }` em recursos críticos
- Usa `count` quando deveria ser `for_each`
- Esquece `backend` no init
- Inline policies em vez de `aws_iam_policy_document`

**Workflow do agente (instrua no AGENTS.md ou skill):**

```bash
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan -detailed-exitcode
# Só DEPOIS de você revisar o plan:
terraform apply tfplan
```

**Dica de prompt:**

> "Implemente conforme ADR-0007. Antes de qualquer apply, mostra o plan e espera minha confirmação. Não use `count`, use `for_each` com map. Pin de versão exato no required_providers."

### Docker

**Skill `dockerfile-hardening` deve cobrir:**

- Multi-stage sempre
- `USER` non-root explícito
- `HEALTHCHECK` obrigatório
- Image tag pin (`python:3.12.7-slim`, nunca `python:slim`)
- `.dockerignore` sempre presente
- ARG vs ENV distinção clara
- `--no-cache-dir` no pip, `--frozen-lockfile` no npm
- Scan com Trivy antes de push

**Prompt útil:**

> "Audite todos os Dockerfiles do repo. Pra cada um, liste violações dos padrões CIS Docker Benchmark. Não modifique ainda — só relatório."

### Kubernetes / AKS

**Regra GitOps absoluta:**

> Mudanças vão via PR nos repos `argocd-manifests-production` / `argocd-manifests-qa`. **Nenhum** `kubectl apply` direto em prod.

Isso vai no AGENTS.md global. No `permission` do Engineer, `kubectl apply*` em `ask` (e treina pra ele dizer "não posso, vai por GitOps").

**Padrões que o agente sempre erra:**

- Esquece `resources.requests` (e quebra autoscaler)
- Esquece `safe-to-evict: true` nas annotations
- Probe path errado (`/healthz` quando a app só tem `/health`)
- `targetPort` errado pra .NET (deveria ser 8080 nas imagens oficiais .NET 8+)
- Esquece PDB
- Esquece NetworkPolicy

**Skill `k8s-manifest-gitops`:** encapsula tudo isso + naming convention + tolerations dos nodepools.

### ECS / Fargate

- Task definition revisionada — agente tende a sobrescrever em vez de criar nova revisão
- Env vars com hierarquia: `ConfigOne__SubKey`, `ConfigOne__Other` (nested com `__` no .NET)
- Capacity provider vs launch type — instrua explicitamente

### AWS (geral)

- **Auth em pipelines**: OIDC sempre. Documente nas skills que `AWSCLI@1` quebra role chaining
- Logs do CloudFront Function: o agente sempre esquece que dá pra inspecionar via `aws cloudfront test-function`

### Azure

- **App Registration vs Service Principal** — agente confunde. Skill deve deixar explícito
- **Key Vault references** em App Service / Container Apps — sintaxe `@Microsoft.KeyVault(...)` quase sempre erra na primeira
- **Application Gateway path-based routing** — vira skill se você tem padrão recorrente

---

## M9 — Anti-patterns e armadilhas

1. **Description genérica em subagent.** Nunca dispara automaticamente. Capricha.

2. **Confiar em "você nunca faz X" no prompt.** Permission é a única garantia. Prompt ajuda.

3. **Free model em código de cliente.** Big Pickle / Nemotron Free / etc usam dados pra treino. Pra trabalho de cliente: Anthropic/OpenAI diretos ou Ollama local.

4. **MCP com todos os domínios.** Enche contexto, degrada qualidade. Filtre.

5. **Não usar git worktrees pra paralelismo.** Dois agents no mesmo working tree = merge conflict autoinfligido.

6. **Não revisar ADR antes de mandar pro Engineer.** O gate humano é obrigatório. Sempre.

7. **Pin de versão esquecido.** Sem skill que force, o agente bota `latest` em tudo.

8. **Esquecer de comitar `.opencode/` e `AGENTS.md`.** Aí ninguém do time tem o setup.

9. **Acreditar no agente que diz "plan limpo".** Leia o plan você mesmo. Sempre.

10. **Skills inchadas.** Cada SKILL.md deve caber numa tela. Se passar disso, quebra em sub-skills ou move pra `references/`.

---

## M10 — Roteiro de adoção (4 semanas)

### Semana 1 — Fundamentos

- Instala OpenCode
- Login no Zen (ou config Anthropic direto)
- `/init` num repo seu pra gerar AGENTS.md
- Brincar no Plan mode em tarefas read-only

### Semana 2 — Agents básicos

- Cria `architect` e `devops-engineer` em `.opencode/agents/`
- Configura permissions corretas
- Faz o fluxo ADR → implementação pelo menos uma vez

### Semana 3 — MCPs e skills

- Adiciona Azure DevOps MCP (read-only inicialmente)
- Adiciona AWS MCP
- Cria as 2 skills mais úteis pro dia a dia (sugestão: `terraform-aws` e `k8s-manifest-gitops`)

### Semana 4 — Paralelismo e maturação

- Aprende `<Leader>+Down` e navegação de sessões filhas
- Usa git worktrees pra rodar duas tarefas em paralelo
- Adiciona `@reviewer` subagent
- Refina descriptions baseado no que disparou e o que não disparou

---

## TL;DR (cola pra parede)

1. **Plan antes de Build.** Tab alterna.
2. **Permissions são guardrail. Prompt é orientação.**
3. **Tudo é arquivo, tudo é Git** — agents, skills, AGENTS.md, opencode.json.
4. **Description vende o subagent.** Genérica = nunca dispara.
5. **Paralelismo limpo = git worktrees.**
6. **MCPs read-only primeiro, write depois.**
7. **Free models = ok pra estudo, perigoso pra cliente.**
8. **Skills encapsulam "como vocês fazem aqui".** Sem skill, o agente improvisa.
9. **ADR é o handoff.** Architect propõe, humano aprova, Engineer implementa.
10. **Sempre leia o plan.** Não terceirize esse step.
