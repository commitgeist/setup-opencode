# setup-opencode

Setup padronizado de [OpenCode](https://opencode.ai) para times de DevOps/SRE.
Um comando instala: agentes com guardrails, skills com scripts e templates,
commands, ADR workflow e config validada — tudo adaptado à sua stack.

---

## O que é OpenCode?

[OpenCode](https://opencode.ai) é um terminal de IA agêntico — um TUI (terminal UI)
que conecta modelos de linguagem a ferramentas reais (bash, leitura/escrita de arquivos,
APIs) através de **agentes** com papéis e permissões definidas.

Conceitos-chave:

| Conceito | O que é | Exemplo |
|---|---|---|
| **Agente** | Um "profissional" com modelo, ferramentas e permissões próprias | `architect` planeja, `devops-engineer` executa |
| **Skill** | Pacote de instruções + scripts para uma área específica | `terraform-aws`, `k8s-manifest-gitops` |
| **MCP** | Conexão com API externa (AWS, Azure DevOps, K8s, etc.) | O agente consulta e opera recursos reais |
| **Command** | Atalho para um workflow comum | `/new-adr`, `/validate-all` |

> Este repo **não é o OpenCode** — é um setup que configura o OpenCode para
> DevOps/SRE com agentes seguros, skills com trilhos e workflow baseado em ADR.

---

## Comece por aqui

### 0. Pré-requisitos

```bash
# 1. Instalar o OpenCode (o motor)
curl -fsSL https://opencode.ai/install | bash

# 2. Dependências do setup
jq --version    # apt install jq / brew install jq
bash --version  # precisa 4.3+ (macOS: brew install bash)
node --version  # 20+ (para MCPs npm-based)

# 3. Chave de API (escolha um)
#    - OpenCode Zen: opencode auth login (tem modelos free)
#    - Anthropic: export ANTHROPIC_API_KEY=...
#    - OpenAI: export OPENAI_API_KEY=...
#    - Ollama local: ollama serve (100% privado, sem API key)
```

### 1. Instalar o setup

```bash
git clone https://github.com/commitgeist/setup-opencode.git
cd setup-opencode
./setup.sh
```

O wizard pergunta sua stack (cloud, CI/CD, IaC, K8s, bancos, modelos) e
gera tudo personalizado. Em ~2 minutos você tem agentes, skills, commands
e ADR workflow prontos.

> Modo não-interativo (padronizar time / CI):
> `cp answers.env.example answers.env && ./setup.sh --answers answers.env`

### 2. Entender o fluxo

O coração do setup é o **ADR** (Architecture Decision Record) — um documento
que registra **o quê** vai ser feito, **por quê**, quais alternativas foram
descartadas e **como** implementar passo a passo. Em vez de o agente improvisar,
ele segue um plano documentado, revisado por humano e versionado no Git.

> Sem ADR → agente improvisa e erra. Com ADR → agente segue plano auditável.

```
┌───────────────┐     ┌──────────┐     ┌──────────────────┐     ┌──────────┐
│   architect   │────▶│  HUMANO  │────▶│ devops-engineer  │────▶│ @reviewer│
│ planeja e gera│     │ revisa e │     │ implementa passo │     │ valida   │
│ o ADR         │     │ aprova   │     │ a passo          │     │ contra   │
└───────────────┘     └──────────┘     └──────────────────┘     │ o ADR    │
                                                                └──────────┘
```

1. **architect** gera `docs/adr/0001-titulo.md` com plano completo
2. **Você** revisa e aprova (gate humano obrigatório)
3. **devops-engineer** lê o ADR e executa passo a passo
4. **@reviewer** compara implementação vs ADR e aponta desvios
5. **Você** abre o PR

#### Os 3 agentes em detalhe

O setup instala um trio de agentes com separação rígida de poderes.
Cada um tem seu modelo, permissões e temperatura — ninguém sai da caixa:

```
       ┌─────────────────────────────────────────────────────────┐
       │                    architect                            │
       │  ORQUESTRADOR — planeja, gera ADR                      │
       │  mode: primary │ bash: deny │ write: só docs/adr/      │
       │  Nunca implementa. Nunca executa comando.              │
       └────────────────────────┬────────────────────────────────┘
                                │ gera ADR
                                ▼
       ┌─────────────────────────────────────────────────────────┐
       │                     HUMANO                              │
       │  Gate obrigatório — lê, questiona, aprova ou rejeita   │
       └────────────────────────┬────────────────────────────────┘
                                │ ADR aprovado
                                ▼
       ┌─────────────────────────────────────────────────────────┐
       │                 devops-engineer                         │
       │  OPERADOR EXECUTOR — implementa conforme o ADR         │
       │  mode: primary │ bash: allow │ write: tudo             │
       │  apply = pede confirmação │ destroy/delete = bloqueado │
       └────────────────────────┬────────────────────────────────┘
                                │ implementou
                                ▼
       ┌─────────────────────────────────────────────────────────┐
       │                    @reviewer                            │
       │  OPERADOR VALIDADOR — compara código vs ADR            │
       │  mode: subagent │ bash: read-only │ write: bloqueado   │
       │  Só pode: plan, validate, fmt, get, diff, describe     │
       └─────────────────────────────────────────────────────────┘
```

| Agente | Papel | Escrever arquivos | Executar bash | Destruir recursos |
|---|---|---|---|---|
| `architect` | Orquestrador | Só `docs/adr/*` | ❌ Bloqueado | ❌ |
| `devops-engineer` | Executor | ✅ Tudo | ✅ (apply=ask) | ❌ deny |
| `reviewer` | Validador | ❌ Bloqueado | 🔍 Só leitura | ❌ |
| `suporte` | Troubleshoot | ❌ Bloqueado | 🔍 Só leitura | ❌ |

O handoff entre eles é via **arquivo** (o ADR). O architect escreve, o
engineer lê e executa, o reviewer lê e valida. Sem improvisação.

### 3. Ver exemplos reais de ADR

- [Criar recurso (S3 + CloudFront)](docs/examples/0001-criar-bucket-s3-cdn.md) — exemplo completo de provisionamento
- [Troubleshooting (CrashLoopBackOff)](docs/examples/0002-troubleshooting-pod-crashloop.md) — exemplo de diagnóstico e correção

### 4. Como usar na vida real

> **Importante:** o setup-opencode é um **instalador**, não o repo onde você trabalha.
> Você roda o setup dentro do repo do seu projeto (ou globalmente) e depois trabalha
> no seu repo normalmente com `opencode`.

#### Exemplo completo: subir um cluster ECS com Terraform

```bash
# ── 1. Criar o repo do projeto ──
mkdir infra-ecs && cd infra-ecs
git init

# ── 2. Rodar o setup (uma vez só) ──
#    Pode clonar ou apontar direto pro script
git clone https://github.com/commitgeist/setup-opencode.git /tmp/setup-opencode
/tmp/setup-opencode/setup.sh
#
#   Wizard pergunta:
#     Cloud? → AWS
#     CI/CD? → Azure Pipelines (ou GitHub Actions)
#     IaC?   → Terraform
#     K8s?   → Não
#     Banco? → Nenhum
#     Modelo? → free-zen (ou anthropic se tiver key)
#     Agentes? → architect, devops-engineer, reviewer
#
#   Resultado: opencode.json, agents/, skills/, commands/,
#   COMECE-AQUI.md, CHEATSHEET.md, docs/adr/, AGENTS.md

# ── 3. Abrir o OpenCode (você começa no architect) ──
opencode
```

**No architect** — pedir o plano:

```
> Planeje a criação de um cluster ECS Fargate na AWS para a aplicação
> "api-pagamentos" (.NET 8, porta 8080). Preciso de:
> - VPC com subnets públicas e privadas
> - ALB com HTTPS (certificado ACM)
> - ECS Cluster Fargate com service e task definition
> - ECR para as imagens
> - CloudWatch logs
> - Autoscaling baseado em CPU (min 2, max 10)
> Região us-east-1, tudo via Terraform.
```

O architect gera `docs/adr/0001-criar-ecs-fargate-api-pagamentos.md` com:
- Contexto e motivação
- Decisão (Fargate vs EC2, por quê)
- Alternativas descartadas
- Estimativa de custo
- **Implementation Guidelines** com passo a passo numerado

**Você revisa o ADR** — lê, ajusta se necessário, aprova.

**Tab → devops-engineer** — mandar implementar:

```
> Implemente docs/adr/0001-criar-ecs-fargate-api-pagamentos.md
> Um passo por vez. Mostre o plan antes de qualquer apply.
```

O engineer:
1. Cria os módulos `.tf` (VPC, ALB, ECS, ECR, IAM)
2. Roda `terraform fmt` + `terraform validate` + `tflint` + `checkov`
3. Executa `terraform plan` e mostra o resultado
4. Pede confirmação antes do `apply`
5. Valida que o serviço está healthy

**@reviewer** — validar:

```
> @reviewer valide a implementação contra docs/adr/0001-criar-ecs-fargate-api-pagamentos.md
```

O reviewer compara o código gerado vs o ADR e aponta desvios
(porta errada, faltou autoscaling, security group aberto demais, etc).

**Você abre o PR** — com ADR, código e validação documentados.

#### Resumo visual

```
setup-opencode/setup.sh  ──▶  seu-repo-de-infra/
                                ├── opencode.json      (config gerada)
                                ├── .opencode/agents/  (agentes com guardrails)
                                ├── .opencode/skills/  (terraform-aws, ecs-deploy, etc)
                                ├── docs/adr/          (seus ADRs vão aqui)
                                └── ... seu código Terraform, manifestos, etc
```

O setup configura. O OpenCode executa. Os agentes seguem os ADRs.
Depois de rodar o setup, você **esquece ele** e trabalha no seu repo.

### 5. Usar o OpenCode pra aprender OpenCode

O próprio OpenCode lê os arquivos do repo. Então depois de rodar o setup
dentro deste repo, você pode pedir pra ele te ensinar usando o material
que já está aqui:

```bash
cd setup-opencode
opencode
```

#### Aprender com o curso

```
> Leia docs/curso-opencode-devops.md e me explique o módulo M4 (skills)
> como se eu nunca tivesse criado uma skill antes
```

```
> Com base em docs/curso-opencode-devops.md, quais são os 3 erros mais
> comuns que o agente comete sem skill? Me dá exemplo prático de cada
```

#### Aprender com os exemplos de ADR

```
> Leia docs/examples/0001-criar-bucket-s3-cdn.md e me explique por que
> cada seção existe e o que eu deveria pensar ao preencher
```

```
> Compare os dois ADRs em docs/examples/ e me diga: qual a diferença
> de estrutura entre um ADR de recurso novo vs um de troubleshooting?
```

#### Entender o que o setup gerou

```
> Leia o opencode.json que foi gerado e me explique cada MCP configurado:
> o que ele faz, quando usar e quando NÃO usar
```

```
> Leia os agentes em .opencode/agents/ e me explique as permissões de cada
> um. O que o architect pode fazer que o engineer não pode? E vice-versa?
```

#### Aprender a criar coisas novas

```
> Leia docs/ENRIQUECER-SETUP.md e me guie passo a passo pra criar uma
> skill nova chamada "helm-deploy" que padronize deploy via Helm charts
```

```
> Com base em templates/agents/architect.md.tpl, me ensine como criar um
> agente novo "secops" que só pode ler e nunca pode executar bash
```

#### Simular cenários

```
> Simule que sou novo no time. Com base no COMECE-AQUI.md e no CHEATSHEET.md,
> me faça um onboarding de 15 minutos: o que eu preciso saber pra começar
> a operar sem quebrar nada?
```

```
> Finja que um pod está em CrashLoopBackOff. Me guie pelo processo de
> diagnóstico usando o agente @suporte — quais comandos ele rodaria?
```

> **Dica:** quanto mais específico o prompt, melhor o resultado. Em vez de
> "me ensina sobre skills", peça "leia o arquivo X e me explique Y como se
> eu fosse Z".

### 6. Aprofundar

| Recurso | O que é |
|---|---|
| `COMECE-AQUI.md` | Gerado pelo setup — ecossistema, níveis Bronze→Platina, quickstart |
| `CHEATSHEET.md` | Gerado pelo setup — referência rápida de agentes, MCPs e permissões |
| [docs/ENRIQUECER-SETUP.md](docs/ENRIQUECER-SETUP.md) | Como adicionar agentes, skills e commands |
| [docs/curso-opencode-devops.md](docs/curso-opencode-devops.md) | Curso completo de OpenCode para DevOps |
| [docs/Agentic_Terminal_Playbook.pdf](docs/Agentic_Terminal_Playbook.pdf) | Playbook de terminal agêntico |
| [docs/OpenCode_AI_Mastery.pdf](docs/OpenCode_AI_Mastery.pdf) | Guia avançado de AI no terminal |

---

## Comandos úteis no dia a dia

Dentro do OpenCode, esses prompts cobrem 80% do trabalho real:

### Planejamento

```
> Planeje a criação de <recurso>. Considere custo, segurança e rollback.
> Gere o ADR em docs/adr/

> Preciso migrar <serviço> de <origem> para <destino>. Analise riscos,
> estime custo e proponha um ADR com implementation guidelines.
```

### Implementação

```
> Implemente docs/adr/0001-titulo.md, um passo por vez.
> Mostre o plan antes de qualquer apply e espere minha confirmação.

> Roda terraform fmt, validate, tflint e checkov neste módulo.
> Só me mostra se tiver erro.

> Crie o Dockerfile pra esta app .NET 8 seguindo CIS Benchmark.
> Multi-stage, non-root, healthcheck, pin de versão.
```

### Validação e review

```
> @reviewer valide a implementação contra docs/adr/0001-titulo.md

> Audite todos os Dockerfiles do repo. Pra cada um, liste violações
> de segurança. Não modifique — só relatório.

> /validate-all
```

### Troubleshooting

```
> Os pods do deployment X estão em CrashLoopBackOff. Diagnostique:
> verifique logs, events, describe e me dê a causa raiz.

> O terraform plan está mostrando destroy de um recurso que não deveria.
> Analise o state e me explique o que está causando.
```

### Workflow rápido

```
> /new-adr                    ← cria ADR com numeração automática
> /validate-all               ← roda todas as validações das skills
> /onboarding-app             ← onboarding de nova aplicação
```

---

## Modelos recomendados

### Se você paga (melhor qualidade)

| Agente | Modelo | Por quê |
|---|---|---|
| architect | `anthropic/claude-opus-4-5` | Melhor em planejamento e raciocínio longo |
| devops-engineer | `anthropic/claude-sonnet-4-6` | Rápido, bom em código e IaC |
| reviewer/suporte | `anthropic/claude-haiku-4-5` | Barato, suficiente pra validação read-only |

### Se você quer free (funciona com trilhos)

| Tier | architect | engineer | reviewer |
|---|---|---|---|
| **Zen** | `opencode/kimi-k2.5-free` | `opencode/glm-4.7-flash` | `opencode/glm-4.7-flash` |
| **OpenRouter** | `openrouter/deepseek/deepseek-r1:free` | `openrouter/qwen/qwen3-coder:free` | `openrouter/meta-llama/llama-3.3-70b-instruct:free` |
| **Ollama (local)** | `ollama/qwen2.5-coder:32b` | `ollama/qwen2.5-coder:14b` | `ollama/llama3.1:8b` |

> IDs de modelos free mudam com o tempo. Confirme com `/models` no TUI.

### Quando usar o quê

- **Estudo pessoal**: Zen free ou Ollama — zero custo
- **Código de cliente**: Anthropic/OpenAI direto — zero-retention
- **100% privado**: Ollama local — nenhuma chamada sai da máquina
- **Experimentar**: OpenRouter — variedade, mas sem garantia de provedor

---

## Free + ADR: funciona? Por quê?

**Resposta curta: sim, funciona — porque o ADR compensa a fraqueza do modelo.**

Modelos free são piores que frontier models em 3 coisas:
1. **Contexto longo** — se perdem em tarefas grandes
2. **Raciocínio multi-step** — pulam passos, alucinam configurações
3. **Consistência** — cada resposta pode ser diferente da anterior

O workflow ADR + skills foi desenhado exatamente pra neutralizar isso:

### Como os trilhos compensam

| Fraqueza do modelo free | Como o setup compensa |
|---|---|
| Se perde em tarefa grande | ADR divide em passos numerados — "implemente o passo 1 e pare" |
| Alucina configurações | Skills trazem templates com placeholders — o modelo substitui, não inventa |
| Pula validações | Scripts prontos (`scripts/validate.sh`) rodam fmt/validate/tflint/checkov |
| Improvisa padrões | AGENTS.md e skills definem naming, portas, tags, policies explicitamente |
| Faz coisas proibidas | Permissions bloqueiam por config — `destroy: deny`, não por instrução |
| Perde contexto entre turnos | O ADR é o contexto — está no arquivo, não na memória do modelo |

### Hábitos que mantêm free nos trilhos

1. **Plan mode primeiro** (`Tab`) — só vá pra Build com plano claro
2. **Um passo por vez** — "implemente o passo 1 e pare" > "implemente tudo"
3. **Prompts curtos e diretos** — contexto longo satura modelo pequeno
4. **Use os scripts** — `scripts/validate.sh` pega erros que o modelo não vê
5. **Tarefa muito complexa?** — aceite que precisa de modelo melhor, ou divida mais

### Por que ADR é o formato ideal pra agentes

O ADR não é burocracia — é **input machine-readable**:

```
┌─────────────────────────────┐
│  ADR = contrato entre       │
│  humano e agente            │
│                             │
│  Contexto    → o agente     │
│                entende o    │
│                problema     │
│                             │
│  Decisão     → o agente     │
│                sabe o que   │
│                fazer        │
│                             │
│  Guidelines  → o agente     │
│                sabe COMO    │
│                fazer, passo │
│                a passo      │
│                             │
│  Critérios   → o agente     │
│                sabe quando  │
│                terminou     │
└─────────────────────────────┘
```

Sem ADR, você depende do modelo "entender" o que você quer.
Com ADR, o modelo **lê** o que precisa fazer. É a diferença entre
"improvise um cluster ECS" e "siga estes 4 passos e valide com estes critérios".

> **Conclusão prática:** modelo free + ADR + skills com trilhos funciona pra
> 80% das tarefas de infra. Os 20% restantes (arquitetura complexa, decisões
> com muitas variáveis) pedem um modelo forte no architect — e só nele.

---

## O que ele instala

| Componente | Condição | O que é |
|---|---|---|
| `agents/architect.md` | selecionado | Planeja e gera ADRs em `docs/adr/` — write bloqueado fora dali, bash deny |
| `agents/devops-engineer.md` | selecionado | Executor: implementa ADRs; `apply` = ask, `delete/destroy` = deny |
| `agents/reviewer.md` | selecionado | Subagent read-only: valida contra o ADR (`@reviewer`) |
| `agents/suporte.md` | selecionado | Diagnóstico read-only de incidentes |
| skill `terraform-aws` | AWS + Terraform | Workflow com checkpoints + `scripts/validate.sh` (fmt/validate/tflint/checkov) |
| skill `ecs-deploy` | AWS | Mapa mental ECS, template de task definition, script de rollout |
| skill `k8s-manifest-gitops` | Kubernetes | Template de Deployment hardened + validador (placeholders, :latest, kube-linter) |
| skill `azure-pipelines-oidc` | Azure Pipelines + AWS | Padrão OIDC/role-chaining + step template (regra do AWSCLI@1) |
| skill `postgres-dba` | PostgreSQL | Queries prontas de diagnóstico (locks, bloat, slow queries) |
| commands | sempre | `/new-adr`, `/validate-all`, `/onboarding-app` |
| `docs/adr/` | escopo local | TEMPLATE + ciclo Proposed → Approved → Implemented |
| `opencode.json` | sempre | MCPs condicionais (aws, azure-devops, terraform, kubernetes), gerado via **jq** e validado |
| `AGENTS.md` | sempre | Convenções enxutas + política de tool-use |
| `COMECE-AQUI.md` | sempre | Guia completo: ecossistema, ADR, níveis Bronze→Platina, quickstart com seus modelos |
| `CHEATSHEET.md` | sempre | Referência rápida: agentes, MCPs, permissões, como criar agente |

## Filosofia

**Papel = agent, área de conhecimento = skill.** Agents existem quando
precisam de permissions/modelo/isolamento próprios (architect, engineer,
reviewer, suporte). DBA, ECS, Terraform são conhecimento → skills,
carregadas sob demanda por qualquer agente.

**Guardrail é permission, não prompt.** O que é proibido (delete, destroy,
push na main) está bloqueado por config — prompt é orientação, permission
é garantia.

**Trilhos para modelos free.** Skills trazem workflow passo a passo com
checkpoints, scripts prontos (`scripts/validate.sh`) e templates com
placeholders. O modelo segue trilho em vez de improvisar — é o que
mantém modelo gratuito utilizável em tarefa real.

## Modelos free

O wizard tem presets: `free-zen` (OpenCode Zen), `free-openrouter`,
`free-ollama` (local/privado), além de anthropic/openai/custom.
Os IDs free mudam com o tempo — **confirme com `/models` no TUI** e
ajuste no frontmatter de `agents/*.md` se necessário.

> ⚠️ Modelos free de provedores cloud podem usar seus dados para treino.
> Não use com código sensível de cliente; para isso, `free-ollama` (local).

## Segurança do gerador

- `opencode.json` montado 100% via `jq` → JSON sempre válido
- `jq empty` valida o resultado antes de terminar
- Arquivos existentes preservados em `*.bak.<timestamp>` (idempotente)
- Prompts do wizard vão para stderr (não contaminam capturas)

## Desenvolvimento

```bash
bash -n setup.sh                                  # sintaxe
shellcheck setup.sh templates/skills/*/scripts/*.sh
bats tests/                                       # 10 testes (usa tests/fixtures/answers.env)
```

CI em `azure-pipelines.yml` roda os três em todo PR.

## Estrutura

```
setup-opencode/
├── setup.sh                 # wizard + instalador (só copia, substitui e valida)
├── answers.env.example      # respostas p/ modo não-interativo
├── azure-pipelines.yml      # CI: shellcheck + bats
├── .gitignore
├── docs/
│   ├── ENRIQUECER-SETUP.md  # guia de como evoluir o setup
│   ├── examples/            # ADRs de exemplo (recurso novo + troubleshooting)
│   ├── curso-opencode-devops.md
│   ├── Agentic_Terminal_Playbook.pdf
│   └── OpenCode_AI_Mastery.pdf
├── templates/
│   ├── agents/*.md.tpl      # placeholder {{MODEL}} substituído por papel
│   ├── commands/*.md
│   ├── CHEATSHEET.md        # referência rápida (copiado durante install)
│   ├── docs/adr/{README,TEMPLATE}.md
│   └── skills/<nome>/{SKILL.md,scripts/,templates/}
└── tests/
    ├── setup.bats
    └── fixtures/answers.env
```
