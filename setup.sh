#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes intencionais ($schema e backticks literais)
set -euo pipefail

# ═════════════════════════════════════════════════════════
# OpenCode Setup v2 — instalador de templates
#
# Uso:
#   ./setup.sh                      # interativo
#   ./setup.sh --answers ans.env    # não-interativo (CI / padronização de time)
#   ./setup.sh --help
#
# Arquitetura: os arquivos vivem em templates/ (versionados, diffáveis).
# Este script só pergunta, copia, substitui placeholders e valida.
# O único arquivo montado dinamicamente é o opencode.json — via jq,
# garantindo JSON válido sempre.
# ═════════════════════════════════════════════════════════

VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL_DIR="$SCRIPT_DIR/templates"

# ── cores (desligam se stdout não é terminal) ──
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; CYAN=$'\033[0;36m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
else
  RED=""; GREEN=""; CYAN=""; YELLOW=""; NC=""
fi

info() { echo "${CYAN}[setup]${NC} $*"; }
ok()   { echo "${GREEN}[ok]${NC}   $*"; }
warn() { echo "${YELLOW}[warn]${NC} $*" >&2; }
err()  { echo "${RED}[err]${NC}  $*" >&2; }

usage() {
  cat <<'EOF'
OpenCode Setup v2

Uso:
  ./setup.sh                     Modo interativo (wizard)
  ./setup.sh --answers FILE      Modo não-interativo: lê respostas de FILE
  ./setup.sh --help              Esta ajuda

Variáveis aceitas no arquivo de respostas (ver answers.env.example):
  SCOPE, CLOUDS, CICD, AZDO_ORG, AWS_REGION, IAC, USE_K8S, DBS,
  AGENTS, MODEL_TIER, MODEL_PLANNER, MODEL_EXECUTOR, MODEL_REVIEWER
EOF
}

# ── guarda de versão do bash (namerefs exigem 4.3+) ──
if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3) )); then
  err "bash >= 4.3 necessário (este é ${BASH_VERSION}). No macOS: brew install bash"
  exit 1
fi

# ── parse de argumentos ──
NON_INTERACTIVE=0
ANSWERS_FILE=""
while (( $# )); do
  case "$1" in
    --answers) ANSWERS_FILE="${2:?--answers exige um arquivo}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) err "Flag desconhecida: $1"; usage; exit 1 ;;
  esac
done

if [[ -n "$ANSWERS_FILE" ]]; then
  [[ -f "$ANSWERS_FILE" ]] || { err "Arquivo de respostas não encontrado: $ANSWERS_FILE"; exit 1; }
  # shellcheck source=/dev/null
  source "$ANSWERS_FILE"
  NON_INTERACTIVE=1
  info "Modo não-interativo: $ANSWERS_FILE"
fi

# ── dependências duras ──
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Dependência ausente: $1 — $2"; exit 1; }
}
require_cmd jq "instale: apt install jq | brew install jq"
[[ -d "$TPL_DIR" ]] || { err "templates/ não encontrado ao lado do script"; exit 1; }

# ═════════════════════════════════════════════════════════
# Helpers de pergunta
#   - prompts vão para STDERR (não contaminam $(captura))
#   - em modo não-interativo, usam a variável já definida ou o default
# ═════════════════════════════════════════════════════════

ask() { # ask VAR "pergunta" "default"  → ecoa a resposta
  local var="$1" prompt="$2" default="$3" current answer
  current="${!var:-}"
  if (( NON_INTERACTIVE )); then
    echo "${current:-$default}"
    return
  fi
  read -r -p "${CYAN}?${NC} ${prompt} [${default}]: " answer
  echo "${answer:-$default}"
}

pick() { # pick VAR "pergunta" "opt1,opt2,..."  → ecoa a escolhida
  local var="$1" prompt="$2" options="$3" current
  current="${!var:-}"
  if (( NON_INTERACTIVE )); then
    echo "${current:-${options%%,*}}"
    return
  fi
  local opts=() opt
  IFS=',' read -ra opts <<< "$options"
  echo "${CYAN}?${NC} ${prompt}" >&2
  select opt in "${opts[@]}"; do
    [[ -n "${opt:-}" ]] && { echo "$opt"; break; }
  done
}

multiselect() { # multiselect VAR "pergunta" "opt1,opt2,..." NOME_ARRAY_SAIDA
  local var="$1" prompt="$2" options="$3"
  local -n __ms_out="$4"
  local current="${!var:-}"
  __ms_out=()
  if (( NON_INTERACTIVE )); then
    if [[ -n "$current" ]]; then
      local piece
      IFS=',' read -ra __ms_out <<< "$current"
      local i=0
      for piece in "${__ms_out[@]}"; do
        __ms_out[i]="$(echo "$piece" | xargs)"; ((i++)) || true
      done
    fi
    return
  fi
  local opts=() raw picks=() p i
  IFS=',' read -ra opts <<< "$options"
  echo "${CYAN}?${NC} ${prompt}" >&2
  echo "  (números separados por vírgula, ex: 1,3 — Enter vazio = nenhum)" >&2
  for i in "${!opts[@]}"; do echo "  $((i+1))) ${opts[$i]}" >&2; done
  read -r -p "Escolha: " raw
  [[ -z "$raw" ]] && return
  IFS=',' read -ra picks <<< "$raw"
  for p in "${picks[@]}"; do
    p="${p// /}"
    if [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= ${#opts[@]} )); then
      __ms_out+=("${opts[$((p-1))]}")
    fi
  done
}

has() { # has needle "${array[@]}"
  local needle="$1"; shift
  local x
  for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
  return 1
}

backup_if_exists() { # preserva arquivo/dir existente antes de sobrescrever
  local target="$1"
  if [[ -e "$target" ]]; then
    local bak
    bak="${target}.bak.$(date +%Y%m%d%H%M%S)"
    cp -a "$target" "$bak"
    warn "Existente preservado: $bak"
  fi
}

# ═════════════════════════════════════════════════════════
# 1. ESCOPO
# ═════════════════════════════════════════════════════════
echo ""
echo "${CYAN}╔══════════════════════════════════════╗${NC}"
echo "${CYAN}║      OpenCode Setup Wizard v${VERSION}     ║${NC}"
echo "${CYAN}╚══════════════════════════════════════╝${NC}"
echo ""

SCOPE="$(pick SCOPE "Instalação local (repo atual) ou global (~/.config/opencode)?" "local,global")"

if [[ "$SCOPE" == "global" ]]; then
  TARGET="$HOME/.config/opencode"
  CONFIG_FILE="$TARGET/opencode.json"
  AGENTS_MD="$TARGET/AGENTS.md"
  AGENTS_DIR="$TARGET/agents"
  SKILLS_DIR="$TARGET/skills"
  COMMANDS_DIR="$TARGET/commands"
  ADR_DIR=""   # docs/adr só faz sentido por-repo
else
  TARGET="$(pwd)"
  CONFIG_FILE="$TARGET/opencode.json"
  AGENTS_MD="$TARGET/AGENTS.md"
  AGENTS_DIR="$TARGET/.opencode/agents"
  SKILLS_DIR="$TARGET/.opencode/skills"
  COMMANDS_DIR="$TARGET/.opencode/commands"
  ADR_DIR="$TARGET/docs/adr"
fi
mkdir -p "$AGENTS_DIR" "$SKILLS_DIR" "$COMMANDS_DIR"
[[ -n "$ADR_DIR" ]] && mkdir -p "$ADR_DIR"
info "Destino: $TARGET"

# ═════════════════════════════════════════════════════════
# 2. STACK
# ═════════════════════════════════════════════════════════
echo ""; echo "${YELLOW}--- Cloud ---${NC}"
clouds=()
multiselect CLOUDS "Quais clouds você usa?" "AWS,Azure,GCP" clouds

AWS_REGION="${AWS_REGION:-us-east-1}"   # preserva valor do answers.env se houver
if has AWS "${clouds[@]:-}"; then
  AWS_REGION="$(ask AWS_REGION "Região AWS padrão" "us-east-1")"
fi

echo ""; echo "${YELLOW}--- CI/CD ---${NC}"
CICD="$(pick CICD "Qual CI/CD?" "Azure Pipelines,GitHub Actions,GitLab CI,Nenhum")"
AZDO_ORG="${AZDO_ORG:-}"   # preserva valor do answers.env se houver
if [[ "$CICD" == "Azure Pipelines" ]]; then
  AZDO_ORG="$(ask AZDO_ORG "Organização do Azure DevOps" "minhaorg")"
fi

echo ""; echo "${YELLOW}--- IaC ---${NC}"
IAC="$(pick IAC "Qual IaC?" "Terraform,Pulumi,CloudFormation,Nenhum")"

# backward compat: se answers.env antigo define USE_K8S mas não CONTAINER_ORCH
if [[ -z "${CONTAINER_ORCH:-}" && -n "${USE_K8S:-}" ]]; then
  case "$USE_K8S" in
    Sim) CONTAINER_ORCH="AKS" ;;
    *)   CONTAINER_ORCH="Nenhum" ;;
  esac
fi

echo ""; echo "${YELLOW}--- Container Orchestration ---${NC}"
CONTAINER_ORCH="$(pick CONTAINER_ORCH "Qual orquestrador de containers?" "AKS,ECS,AKS+ECS,Nenhum")"

# backward compat: derive USE_K8S from CONTAINER_ORCH
case "$CONTAINER_ORCH" in
  AKS|AKS+ECS) USE_K8S="Sim" ;;
  *)            USE_K8S="Não" ;;
esac

echo ""; echo "${YELLOW}--- References (configs de referência) ---${NC}"
USE_REFS="$(pick USE_REFS "Criar diretório references/ para configs de referência? (pipeline, manifests, task-def)" "Sim,Não")"

echo ""; echo "${YELLOW}--- Bancos de dados ---${NC}"
dbs=()
multiselect DBS "Quais bancos você administra?" "PostgreSQL,MySQL,SQL Server,Nenhum" dbs

# ═════════════════════════════════════════════════════════
# 3. MODELOS  (com presets FREE — confirme IDs com /models no TUI)
# ═════════════════════════════════════════════════════════
echo ""; echo "${YELLOW}--- Modelos ---${NC}"

# ── dica de descoberta de IDs (só no interativo) ──
if (( ! NON_INTERACTIVE )); then
  echo "" >&2
  echo "${CYAN}╭─ Dica: como descobrir IDs de modelos ─────────────────────────────╮${NC}" >&2
  echo "${CYAN}│${NC}  Os IDs pré-configurados podem estar desatualizados.              ${CYAN}│${NC}" >&2
  echo "${CYAN}│${NC}  Para listar os IDs reais do seu provider, rode em outro terminal:${CYAN}│${NC}" >&2
  echo "${CYAN}│${NC}                                                                   ${CYAN}│${NC}" >&2
  echo "${CYAN}│${NC}    ${GREEN}opencode models${NC}                 # todos os providers         ${CYAN}│${NC}" >&2
  echo "${CYAN}│${NC}    ${GREEN}opencode models opencode${NC}         # só Zen (free)              ${CYAN}│${NC}" >&2
  echo "${CYAN}│${NC}    ${GREEN}opencode models huggingface${NC}      # Hugging Face               ${CYAN}│${NC}" >&2
  echo "${CYAN}│${NC}    ${GREEN}opencode models openrouter${NC}       # OpenRouter                 ${CYAN}│${NC}" >&2
  echo "${CYAN}│${NC}    ${GREEN}opencode models opencode --verbose${NC}  # com detalhes             ${CYAN}│${NC}" >&2
  echo "${CYAN}│${NC}                                                                   ${CYAN}│${NC}" >&2
  echo "${CYAN}│${NC}  Modelos free no Zen geralmente terminam com ${YELLOW}-free${NC} no ID.       ${CYAN}│${NC}" >&2
  echo "${CYAN}│${NC}  Copie o ID exato do output (ex: opencode/deepseek-v4-flash-free) ${CYAN}│${NC}" >&2
  echo "${CYAN}╰───────────────────────────────────────────────────────────────────╯${NC}" >&2
  echo "" >&2
fi

MODEL_TIER="$(pick MODEL_TIER "Como você acessa modelos?" "free-zen,free-openrouter,free-ollama,anthropic,openai,custom")"

model_note=""
case "$MODEL_TIER" in
  free-zen)
    def_planner="opencode/kimi-k2.5-free"
    def_executor="opencode/glm-4.7-flash"
    def_reviewer="opencode/glm-4.7-flash"
    model_note="Zen free: rode /connect e depois /models no TUI para confirmar os IDs free atuais (mudam com o tempo). Atenção: alguns modelos free usam seus dados para treino — não use com código sensível de cliente."
    ;;
  free-openrouter)
    def_planner="openrouter/deepseek/deepseek-r1:free"
    def_executor="openrouter/qwen/qwen3-coder:free"
    def_reviewer="openrouter/meta-llama/llama-3.3-70b-instruct:free"
    model_note="OpenRouter free: confirme os IDs em openrouter.ai/collections/free-models (mudam com frequência). Modelos :free podem usar seus dados para treino — não use com código sensível de cliente."
    ;;
  free-ollama)
    def_planner="ollama/qwen2.5-coder:32b"
    def_executor="ollama/qwen2.5-coder:14b"
    def_reviewer="ollama/llama3.1:8b"
    model_note="Ollama local: 100% privado. Garanta que os modelos foram baixados com 'ollama pull <modelo>'. Hardware fraco = use variantes menores."
    ;;
  anthropic)
    def_planner="anthropic/claude-opus-4-5"
    def_executor="anthropic/claude-sonnet-4-6"
    def_reviewer="anthropic/claude-haiku-4-5"
    ;;
  openai)
    def_planner="openai/gpt-5.2"
    def_executor="openai/gpt-5.2-mini"
    def_reviewer="openai/gpt-5.2-mini"
    model_note="Confirme os IDs atuais com /models no TUI."
    ;;
  *)
    def_planner=""
    def_executor=""
    def_reviewer=""
    ;;
esac

MODEL_PLANNER="$(ask MODEL_PLANNER  "Modelo do ARCHITECT (o mais forte que tiver)" "$def_planner")"
MODEL_EXECUTOR="$(ask MODEL_EXECUTOR "Modelo do ENGINEER (executor)" "$def_executor")"
MODEL_REVIEWER="$(ask MODEL_REVIEWER "Modelo do REVIEWER/SUPORTE (mais leve)" "$def_reviewer")"

# ═════════════════════════════════════════════════════════
# 4. AGENTES  (papéis; conhecimento de área vira skill)
# ═════════════════════════════════════════════════════════
echo ""; echo "${YELLOW}--- Agentes (papéis) ---${NC}"
agents_sel=()
multiselect AGENTS "Quais agentes instalar?" "architect,devops-engineer,reviewer,suporte" agents_sel
if (( ${#agents_sel[@]} == 0 )); then
  agents_sel=(architect devops-engineer reviewer)
  info "Nenhum selecionado — instalando trio padrão: architect, devops-engineer, reviewer"
fi

# default_agent precisa ser PRIMARY (reviewer é subagent)
default_agent=""
for a in "${agents_sel[@]}"; do
  case "$a" in
    architect|devops-engineer|suporte) default_agent="$a"; break ;;
  esac
done
if [[ -z "$default_agent" ]]; then
  agents_sel+=(devops-engineer)
  default_agent="devops-engineer"
  warn "Só subagents selecionados — adicionando devops-engineer como primary/default"
fi

# ═════════════════════════════════════════════════════════
# 5. INSTALAR AGENTES (templates + substituição de modelo)
# ═════════════════════════════════════════════════════════
echo ""
info "Instalando agentes em $AGENTS_DIR ..."

install_agent() { # nome modelo
  local name="$1" model="$2"
  local src="$TPL_DIR/agents/${name}.md.tpl"
  local dst="$AGENTS_DIR/${name}.md"
  [[ -f "$src" ]] || { warn "Template não encontrado: $src — pulando"; return; }
  backup_if_exists "$dst"
  sed -e "s|{{MODEL}}|${model}|g" "$src" > "$dst"
  ok "agent: $name (modelo: $model)"
}

for a in "${agents_sel[@]}"; do
  case "$a" in
    architect)        install_agent architect "$MODEL_PLANNER" ;;
    devops-engineer)  install_agent devops-engineer "$MODEL_EXECUTOR" ;;
    reviewer)         install_agent reviewer "$MODEL_REVIEWER" ;;
    suporte)          install_agent suporte "$MODEL_REVIEWER" ;;
  esac
done

# ═════════════════════════════════════════════════════════
# 6. INSTALAR SKILLS (condicionais por stack — N3 + N6)
# ═════════════════════════════════════════════════════════
echo ""
info "Instalando skills em $SKILLS_DIR ..."

skills_to_install=()
if has AWS "${clouds[@]:-}"; then
  [[ "$IAC" == "Terraform" ]] && skills_to_install+=(terraform-aws)
  # ECS skill when container orch includes ECS
  case "$CONTAINER_ORCH" in
    ECS|AKS+ECS) skills_to_install+=(ecs-deploy) ;;
  esac
fi
[[ "$USE_K8S" == "Sim" ]] && skills_to_install+=(k8s-manifest-gitops)
if [[ "$CICD" == "Azure Pipelines" ]] && has AWS "${clouds[@]:-}"; then
  skills_to_install+=(azure-pipelines-oidc)
fi
has PostgreSQL "${dbs[@]:-}" && skills_to_install+=(postgres-dba)

installed_skills=()
for s in "${skills_to_install[@]:-}"; do
  [[ -z "$s" ]] && continue
  src="$TPL_DIR/skills/$s"
  dst="$SKILLS_DIR/$s"
  [[ -d "$src" ]] || { warn "Skill template não encontrada: $s — pulando"; continue; }
  backup_if_exists "$dst"
  rm -rf "$dst"
  cp -a "$src" "$dst"
  # scripts executáveis
  if [[ -d "$dst/scripts" ]]; then
    chmod +x "$dst/scripts/"*.sh 2>/dev/null || true
  fi
  installed_skills+=("$s")
  ok "skill: $s"
done

# ═════════════════════════════════════════════════════════
# 7. INSTALAR COMMANDS (N5)
# ═════════════════════════════════════════════════════════
echo ""
info "Instalando commands em $COMMANDS_DIR ..."
installed_commands=()
for cmd_file in "$TPL_DIR/commands/"*.md; do
  [[ -e "$cmd_file" ]] || continue
  base="$(basename "$cmd_file")"
  backup_if_exists "$COMMANDS_DIR/$base"
  cp "$cmd_file" "$COMMANDS_DIR/$base"
  installed_commands+=("${base%.md}")
  ok "command: /${base%.md}"
done

# ═════════════════════════════════════════════════════════
# 7b. REFERENCES (configs reais como referência de padrão)
# ═════════════════════════════════════════════════════════
if [[ "$USE_REFS" == "Sim" ]]; then
  echo ""
  info "Criando diretório references/ ..."
  if [[ "$SCOPE" == "global" ]]; then
    REFS_DIR="$TARGET/references"
  else
    REFS_DIR="$TARGET/.opencode/references"
  fi
  mkdir -p "$REFS_DIR"

  # Instalar README guia
  if [[ -f "$TPL_DIR/references/README.md" ]]; then
    cp "$TPL_DIR/references/README.md" "$REFS_DIR/README.md"
  fi

  # Criar subdiretórios baseados no container orch
  case "$CONTAINER_ORCH" in
    AKS)
      mkdir -p "$REFS_DIR/pipeline" "$REFS_DIR/k8s-manifests"
      ;;
    ECS)
      mkdir -p "$REFS_DIR/pipeline" "$REFS_DIR/ecs"
      ;;
    AKS+ECS)
      mkdir -p "$REFS_DIR/pipeline" "$REFS_DIR/k8s-manifests" "$REFS_DIR/ecs"
      ;;
  esac

  # Colocar .gitkeep nos dirs vazios
  find "$REFS_DIR" -type d -empty -exec touch {}/.gitkeep \;
  ok "references/ criado em $REFS_DIR"
  ok "Cole seus arquivos reais (pipeline, manifests, task-def) nesse diretório"
fi

# ═════════════════════════════════════════════════════════
# 7c. PLUGIN DE VALIDAÇÃO DE NAMING
# ═════════════════════════════════════════════════════════
echo ""
info "Instalando plugin de validação ..."
if [[ "$SCOPE" == "global" ]]; then
  PLUGINS_DIR="$TARGET/plugins"
else
  PLUGINS_DIR="$TARGET/.opencode/plugins"
fi
mkdir -p "$PLUGINS_DIR"
if [[ -f "$TPL_DIR/plugins/validate-naming.ts" ]]; then
  backup_if_exists "$PLUGINS_DIR/validate-naming.ts"
  cp "$TPL_DIR/plugins/validate-naming.ts" "$PLUGINS_DIR/validate-naming.ts"
  ok "plugin: validate-naming"
fi

# ═════════════════════════════════════════════════════════
# 8. DOCS/ADR (apenas escopo local)
# ═════════════════════════════════════════════════════════
if [[ -n "$ADR_DIR" ]]; then
  for f in README.md TEMPLATE.md; do
    if [[ ! -f "$ADR_DIR/$f" ]]; then
      cp "$TPL_DIR/docs/adr/$f" "$ADR_DIR/$f"
      ok "docs/adr/$f"
    fi
  done
fi

# CONCEPTS.md — referência: ADR, Runbook, Playbook, Postmortem
if [[ "$SCOPE" == "local" ]]; then
  DOCS_DIR="$TARGET/docs"
  mkdir -p "$DOCS_DIR"
  if [[ ! -f "$DOCS_DIR/CONCEPTS.md" ]]; then
    cp "$TPL_DIR/docs/CONCEPTS.md" "$DOCS_DIR/CONCEPTS.md"
    ok "docs/CONCEPTS.md"
  fi
  # PLUGINS.md — documentação de plugins
  if [[ -f "$TPL_DIR/docs/PLUGINS.md" ]]; then
    cp "$TPL_DIR/docs/PLUGINS.md" "$DOCS_DIR/PLUGINS.md"
    ok "docs/PLUGINS.md"
  fi
fi

# ═════════════════════════════════════════════════════════
# 9. GERAR opencode.json — via jq (JSON válido garantido)
# ═════════════════════════════════════════════════════════
echo ""
info "Gerando $CONFIG_FILE ..."

cfg='{"$schema":"https://opencode.ai/config.json"}'
cfg="$(jq --arg d "$default_agent" '. + {default_agent: $d, mcp: {}}' <<< "$cfg")"

mcps_installed=()
if has AWS "${clouds[@]:-}"; then
  cfg="$(jq --arg r "$AWS_REGION" '.mcp.aws = {
    type: "local",
    command: ["uvx", "awslabs.aws-api-mcp-server@latest"],
    environment: { AWS_REGION: $r },
    enabled: true
  }' <<< "$cfg")"
  mcps_installed+=("aws")
fi

if [[ "$CICD" == "Azure Pipelines" && -n "$AZDO_ORG" ]]; then
  cfg="$(jq --arg o "$AZDO_ORG" '.mcp["azure-devops"] = {
    type: "local",
    command: ["npx", "-y", "@azure-devops/mcp", $o, "-d", "pipelines", "repositories", "work-items"],
    enabled: true
  }' <<< "$cfg")"
  mcps_installed+=("azure-devops")
fi

if [[ "$IAC" == "Terraform" ]]; then
  tf_enabled=true
  command -v docker >/dev/null 2>&1 || { tf_enabled=false; warn "Docker ausente — MCP terraform instalado desabilitado"; }
  cfg="$(jq --argjson e "$tf_enabled" '.mcp.terraform = {
    type: "local",
    command: ["docker", "run", "-i", "--rm", "hashicorp/terraform-mcp-server"],
    enabled: $e
  }' <<< "$cfg")"
  mcps_installed+=("terraform")
fi

if [[ "$USE_K8S" == "Sim" ]]; then
  # opt-in: começa desabilitado (read-only first; habilite quando precisar)
  cfg="$(jq '.mcp.kubernetes = {
    type: "local",
    command: ["npx", "-y", "kubernetes-mcp-server@latest"],
    enabled: false
  }' <<< "$cfg")"
  mcps_installed+=("kubernetes (disabled)")
fi

backup_if_exists "$CONFIG_FILE"
jq . <<< "$cfg" > "$CONFIG_FILE"

# validação final — teria pegado os bugs da v1
jq empty "$CONFIG_FILE" || { err "JSON inválido gerado — abortando"; exit 1; }
ok "Config válida: $CONFIG_FILE"

# ═════════════════════════════════════════════════════════
# 10. GERAR AGENTS.md
# ═════════════════════════════════════════════════════════
echo ""
info "Gerando $AGENTS_MD ..."
backup_if_exists "$AGENTS_MD"

cat <<'HDR' > "$AGENTS_MD"
# Convenções do projeto

> Gerado pelo setup-opencode. Carregado em toda sessão.
> Mantenha ENXUTO: detalhes vão nas skills (carregadas sob demanda).

HDR

{
  echo "## Agentes (papéis — alterne com Tab, invoque subagent com @)"
  echo ""
  for a in "${agents_sel[@]}"; do
    case "$a" in
      architect)       printf -- '- `@architect` — planeja e gera ADRs em docs/adr/ (nunca implementa)\n' ;;
      devops-engineer) printf -- '- `@devops-engineer` — implementa ADRs aprovados\n' ;;
      reviewer)        printf -- '- `@reviewer` — valida implementação contra o ADR (read-only, subagent)\n' ;;
      suporte)         printf -- '- `@suporte` — diagnóstico read-only de incidentes\n' ;;
    esac
  done
  echo ""
  if (( ${#installed_skills[@]} > 0 )); then
    echo "## Skills instaladas (carregam sob demanda)"
    echo ""
    for s in "${installed_skills[@]}"; do
      printf -- '- `%s`\n' "$s"
    done
    echo ""
  fi
  if (( ${#mcps_installed[@]} > 0 )); then
    echo "## MCPs configurados"
    echo ""
    for m in "${mcps_installed[@]}"; do
      printf -- '- %s\n' "$m"
    done
    echo ""
  fi
  echo "## Modelos"
  echo ""
  printf -- '- architect: `%s`\n' "$MODEL_PLANNER"
  printf -- '- devops-engineer: `%s`\n' "$MODEL_EXECUTOR"
  printf -- '- reviewer/suporte: `%s`\n' "$MODEL_REVIEWER"
  echo ""
} >> "$AGENTS_MD"

# ── Naming conventions (dinâmico por container orch) ──
{
  echo "## ⛔ Naming Conventions (OBRIGATÓRIO)"
  echo ""
  echo "ANTES de criar QUALQUER arquivo, verifique esta tabela. Se o nome não bater: PARE e corrija."
  echo ""
  echo "| Tipo | Padrão | Exemplo correto | Exemplo ERRADO |"
  echo "|---|---|---|---|"
  case "$CICD" in
    "Azure Pipelines")
      echo "| Pipeline Azure DevOps | \`.azure-pipelines.yaml\` na raiz do repo | \`.azure-pipelines.yaml\` | \`azure-pipelines.yml\`, \`pipeline.yaml\` |"
      ;;
    "GitHub Actions")
      echo "| GitHub Actions | \`.github/workflows/<nome>.yml\` | \`.github/workflows/ci.yml\` | \`ci.yaml\`, \`.github/ci.yml\` |"
      ;;
    "GitLab CI")
      echo "| GitLab CI | \`.gitlab-ci.yml\` na raiz | \`.gitlab-ci.yml\` | \`gitlab.yml\`, \`.gitlab-ci.yaml\` |"
      ;;
  esac
  echo "| Dockerfile | \`Dockerfile\` (ou \`Dockerfile.<variante>\`) | \`Dockerfile\`, \`Dockerfile.migrations\` | \`dockerfile\`, \`Dockerfile.prod\` |"
  echo "| Terraform | \`main.tf\`, \`variables.tf\`, \`outputs.tf\`, \`providers.tf\`, \`backend.tf\` | \`main.tf\` | \`infra.tf\`, \`resources.tf\` |"
  case "$CONTAINER_ORCH" in
    AKS|AKS+ECS)
      echo "| K8s Deployment | \`deployment-<app>.yaml\` | \`deployment-api.yaml\` | \`deploy.yaml\`, \`api-deployment.yml\` |"
      echo "| K8s Service | \`service-<app>.yaml\` | \`service-api.yaml\` | \`svc.yaml\` |"
      echo "| K8s Ingress | \`ingress-<app>.yaml\` | \`ingress-api.yaml\` | \`ing.yaml\` |"
      echo "| K8s HPA | \`hpa-<app>.yaml\` | \`hpa-api.yaml\` | \`autoscaler.yaml\` |"
      echo "| K8s PDB | \`pdb-<app>.yaml\` | \`pdb-api.yaml\` | \`disruption.yaml\` |"
      echo "| K8s Namespace | \`namespace-<nome>.yaml\` | \`namespace-production.yaml\` | \`ns.yaml\` |"
      echo "| K8s ConfigMap | \`configmap-<app>.yaml\` | \`configmap-api.yaml\` | \`cm.yaml\` |"
      echo "| K8s Secret | \`secret-<app>.yaml\` (SealedSecret) | \`secret-api.yaml\` | \`secrets.yaml\` |"
      echo "| ArgoCD Application | \`application-<app>.yaml\` | \`application-api.yaml\` | \`argoapp.yaml\` |"
      ;;
  esac
  case "$CONTAINER_ORCH" in
    ECS|AKS+ECS)
      echo "| ECS Task Definition | \`task-definition-<app>.json\` | \`task-definition-api.json\` | \`taskdef.json\`, \`td.json\` |"
      echo "| ECS Service | \`service-<app>.json\` (CloudFormation/Terraform) | \`service-api.json\` | \`ecs-svc.json\` |"
      ;;
  esac
  echo "| Shell scripts | \`kebab-case.sh\` | \`deploy-prod.sh\` | \`deployProd.sh\`, \`deploy_prod.sh\` |"
  case "$CICD" in
    "GitHub Actions")
      echo "| GitHub Actions workflow | \`.github/workflows/<nome>.yml\` | \`.github/workflows/deploy.yml\` | \`deploy.yaml\` (GitHub usa .yml) |"
      ;;
    "GitLab CI")
      echo "| GitLab CI | \`.gitlab-ci.yml\` na raiz | \`.gitlab-ci.yml\` | \`gitlab-ci.yaml\` |"
      ;;
  esac
  echo ""
  echo "### Extensões"
  echo ""
  case "$CICD" in
    "Azure Pipelines")
      echo "- YAML para K8s/Azure Pipelines: sempre \`.yaml\` (NUNCA \`.yml\`)"
      ;;
    "GitHub Actions")
      echo "- GitHub Actions: sempre \`.yml\` (padrão do GitHub)"
      echo "- YAML para K8s manifests: sempre \`.yaml\`"
      ;;
    "GitLab CI")
      echo "- GitLab CI: \`.gitlab-ci.yml\` (padrão do GitLab)"
      echo "- YAML para K8s manifests: sempre \`.yaml\`"
      ;;
    *)
      echo "- YAML para K8s manifests: sempre \`.yaml\`"
      ;;
  esac
  echo "- JSON: \`.json\`"
  echo "- Shell: \`.sh\`"
  echo "- Terraform: \`.tf\`"
  echo ""
} >> "$AGENTS_MD"

# ── References (se habilitado) ──
if [[ "$USE_REFS" == "Sim" ]]; then
  {
    echo "## 📁 Configs de referência (references/)"
    echo ""
    echo "O diretório \`references/\` contém arquivos REAIS do seu ambiente."
    echo "ANTES de criar qualquer pipeline, manifest ou task-definition:"
    echo ""
    echo "1. **LEIA** o arquivo de referência correspondente em \`references/\`"
    echo "2. **USE** a mesma estrutura, naming, e padrões"
    echo "3. **ADAPTE** apenas os valores específicos da nova app"
    echo "4. **NÃO** invente padrões — copie do reference"
    echo ""
    echo "Se o reference estiver vazio (só .gitkeep), use o template da skill."
    echo ""
  } >> "$AGENTS_MD"
fi

# ── Pre-flight check obrigatório ──
{
  echo "## ⛔ Pre-flight check (OBRIGATÓRIO antes de criar/editar arquivo)"
  echo ""
  echo "ANTES de criar ou modificar qualquer arquivo de infra, execute mentalmente:"
  echo ""
  echo "1. O nome segue a tabela de Naming Conventions acima?"
  echo "2. A extensão está correta (\`.yaml\` e não \`.yml\`)?"
  echo "3. O caminho está correto (não criar arquivo no lugar errado)?"
  echo "4. Existe um reference em \`references/\`? Se sim, segui o padrão dele?"
  echo "5. Estou usando template da skill ou escrevendo do zero? (NUNCA do zero)"
  echo ""
  echo "Se QUALQUER resposta for NÃO → PARE, corrija, e só então prossiga."
  echo ""
} >> "$AGENTS_MD"

cat <<'FTR' >> "$AGENTS_MD"
## Regras invioláveis

- **GitOps**: mudanças K8s via commit nos repos de manifests; PROIBIDO `kubectl apply/patch` direto em produção
- **Secrets**: apenas Key Vault / Variable Groups — nunca hardcode, nunca em logs
- **Pin de versões**: `~> X.Y` em providers Terraform; SHA ou versão exata em imagens (nunca `:latest`)
- **Valide antes de aplicar**: `terraform plan`, `kubectl diff`, `tflint`, `checkov`
- **Auth AWS em pipelines**: OIDC; após role chaining use `bash` com `env:` explícito (nunca task AWSCLI@1)
- **Fluxo de mudança**: architect gera ADR → humano aprova → engineer implementa → @reviewer valida → PR

## Política de tool use (importante para modelos free)

- NUNCA afirme o estado do ambiente sem verificar com tool antes
- NUNCA invente flags de CLI: confirme com `--help` ou MCP
- Siga os workflows das skills passo a passo, validando cada checkpoint
- Em dúvida, PARE e pergunte — não preencha lacunas com suposição
FTR

ok "AGENTS.md gerado"

# ═════════════════════════════════════════════════════════
# 11. GERAR COMECE-AQUI.md (quickstart personalizado)
# ═════════════════════════════════════════════════════════
COMECE="$TARGET/COMECE-AQUI.md"
backup_if_exists "$COMECE"

cat <<'QSTART' > "$COMECE"
# COMECE AQUI — OpenCode

Setup concluído. Este guia cobre tudo: do primeiro comando ao fluxo corporativo.

---

## O ecossistema (entenda cada peça)

```
┌─────────────────────────────────────────────────────────────┐
│                      OPENCODE                               │
│  Motor que conecta modelo + ferramentas + agentes + MCPs   │
├───────────────┬───────────────────┬─────────────────────────┤
│    TOOLS      │       MCPs        │        SKILLS           │
│  Habilidades  │  Conexões externas│  Pacotes de instrução   │
│  nativas do   │  via MCP protocol │  + scripts prontos      │
│  OpenCode     │                   │                         │
├───────────────┼───────────────────┼─────────────────────────┤
│ • ler arquivo │ • AWS CLI         │ • terraform-aws         │
│ • escrever    │ • Azure DevOps    │ • k8s-manifest-gitops   │
│ • editar      │ • Terraform       │ • ecs-deploy            │
│ • bash        │ • Kubernetes      │ • postgres-dba          │
│ • buscar      │ • web search      │ • azure-pipelines-oidc  │
│ • perguntar   │ • web fetch       │                         │
└───────────────┴───────────────────┴─────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                        AGENTES                              │
│  = model + tools + permissions + instruções + skills        │
│                                                             │
│  Ex: devops-engineer = modelo + aws/k8s MCPs                │
│      + bash (com restrições) + AGENTS.md + SKILL.md         │
└─────────────────────────────────────────────────────────────┘
```

### Tool vs MCP vs Skill vs Agente

| Conceito | O que é | Exemplo |
|---|---|---|
| **Tool** | Capacidade nativa do OpenCode (não precisa instalar) | `read`, `write`, `edit`, `bash`, `grep`, `glob` |
| **MCP** | Conexão com API externa via MCP Protocol (precisa configurar) | AWS, Azure DevOps, Terraform, Kubernetes |
| **Skill** | Pacote de instruções + scripts para uma área específica | `terraform-aws`, `k8s-manifest-gitops` |
| **Agente** | Um "profissional" completo = modelo + tools + MCPs + skills + permissões | `@architect`, `@devops-engineer`, `@reviewer` |

> Visual: Tool é a ***mão*** do agente. MCP é a ***caixa de ferramentas*** conectada.
> Skill é o ***manual de instruções***. Agente é o ***profissional*** que usa tudo junto.

---

## O que é ADR?

**ADR** = Architecture Decision Record. Um documento que registra:

- **Contexto**: qual problema estamos resolvendo
- **Decisão**: o que foi escolhido e por quê
- **Alternativas**: o que foi descartado e o motivo
- **Consequências**: impactos, custos, riscos, rollback
- **Guidelines**: passo a passo para implementar

Os ADRs ficam em `docs/adr/NNNN-titulo.md`. Sempre que alguém perguntar
"por que fizemos assim?", a resposta está no ADR.

> Sem ADR → decisão no achismo. Com ADR → decisão documentada e auditável.

---

## Roteiro dos primeiros 30 minutos

### 1. Abrir e reconhecer o terreno

```bash
opencode
```

- `Tab` alterna entre os primary agents (você começa no default)
- Digite `@` para ver os subagents disponíveis
- Digite `/` para ver os commands instalados (ex: `/new-adr`, `/validate-all`)
- Rode `/models` para confirmar os IDs de modelo disponíveis no seu provider

### 2. Primeira tarefa real (fluxo completo, escolha algo PEQUENO)

```text
1. No architect:  "Gere um ADR para <tarefa pequena, ex: criar Dockerfile da app X>"
2. VOCÊ revisa docs/adr/0001-*.md  (gate humano — sempre)
3. Tab → devops-engineer:  "Implemente docs/adr/0001-*.md, um passo por vez"
4. Ao final:  "@reviewer valide a implementação contra docs/adr/0001-*.md"
```

### 3. Trabalhando com modelos FREE (leia isto)

Os modelos configurados neste setup:

- architect: `{{M_PLANNER}}`
- devops-engineer: `{{M_EXECUTOR}}`
- reviewer/suporte: `{{M_REVIEWER}}`

{{MODEL_NOTE}}

Modelos free se perdem em tarefas longas. Este setup compensa com trilhos:

- **Skills com passo a passo + checkpoints** — siga-os, não improvise
- **Scripts prontos** (`scripts/validate.sh` nas skills) — o agente roda o script em vez de inventar comandos
- **Templates com placeholders** — o agente substitui, não gera do zero
- **Permissions** — o que é proibido está bloqueado por config, não por instrução

Hábitos que mantêm modelo free nos trilhos:

1. **Plan mode primeiro** (Tab) — só vá para Build com plano claro
2. **Um passo por vez** — "implemente o passo 1 e pare" funciona melhor que "implemente tudo"
3. **Prompts curtos e específicos** — contexto longo satura modelo pequeno
4. **Tarefa complexa? Divida** — ou aceite que essa específica pode precisar de um modelo melhor

### 4. Trocar de modelo depois

Edite o frontmatter dos agentes em `agents/*.md` (campo `model:`) ou rode o setup de novo
(os arquivos atuais são preservados em `.bak.<timestamp>`).

---

## Níveis de proficiência

### 🥉 Bronze — Usuário básico

**O que você sabe fazer:**
- Conversar com o chat, pedir pra ler/editar arquivos
- Executar comandos bash via OpenCode
- Usar busca e grep no código

**Arquivos que você precisa conhecer:**
- `AGENTS.md` — instruções que o agente lê automaticamente
- `opencode.json` — configurações do projeto

---

### 🥈 Prata — Conectado ao ecossistema

**O que você sabe fazer:**
- Usar MCPs para interagir com AWS, Azure DevOps, Terraform, K8s
- Carregar skills prontas
- Rodar validações automatizadas (terraform plan, tflint, checkov)
- Saber a diferença entre tool, MCP, skill e agente

**Habilidade chave:** chamar o MCP certo na hora certa.

---

### 🥇 Ouro — Criador de agentes

**O que você sabe fazer:**
- Criar agentes customizados com permissões restritas
- Definir `temperature`, `model`, `tools` diferentes por agente
- Usar `permission` para bloquear ações destrutivas
- Combinar skills com agentes para tarefas complexas

**Habilidade chave:** criar o agente certo pra cada tarefa, com as permissões certas.

---

### 💎 Platina — Workflow corporativo

**O que você sabe fazer:**
- Workflow completo: ADR → Revisão → Implementação → Review → PR
- Múltiplos agentes colaborando (architect planeja, engineer executa, reviewer valida)
- GitOps como única interface (nunca `kubectl apply` direto)
- Infra como código com pin de versões, validações obrigatórias, rollback planejado
- Templates de repo para onboard rápido de novos projetos

**Habilidade chave:** pensar em termos de decisões documentadas, não de comandos avulsos.

---

## Checkup rápido — em qual nível você está?

- [ ] Já usei `Tab` e `@` para alternar entre agentes
- [ ] Já configurei um MCP (AWS, Azure DevOps, K8s, etc.)
- [ ] Já criei meu próprio agente em `opencode.json`
- [ ] Já usei o workflow ADR → Implementação → Review → PR
- [ ] Já criei uma skill ou command custom

---

## Evoluir o setup

- Nova convenção recorrente? → adicione na skill correspondente (não no AGENTS.md)
- Workflow que você repete? → vire um command em `commands/`
- Agente errou algo? → anote e transforme a correção em checkpoint da skill
- Quer adicionar agente/skill/command? → veja `docs/ENRIQUECER-SETUP.md`

## Material complementar

- `CHEATSHEET.md` — referência rápida de agentes, MCPs e permissões
- `docs/Agentic_Terminal_Playbook.pdf` — playbook de terminal agêntico
- `docs/OpenCode_AI_Mastery.pdf` — guia avançado de AI no terminal
QSTART

sed -i \
  -e "s|{{M_PLANNER}}|${MODEL_PLANNER}|" \
  -e "s|{{M_EXECUTOR}}|${MODEL_EXECUTOR}|" \
  -e "s|{{M_REVIEWER}}|${MODEL_REVIEWER}|" \
  -e "s|{{MODEL_NOTE}}|${model_note:-Confirme os IDs de modelo com /models no TUI.}|" \
  "$COMECE"

ok "COMECE-AQUI.md gerado"

# ── CHEATSHEET ──
CHEAT_SRC="$TPL_DIR/CHEATSHEET.md"
CHEAT_DST="$TARGET/CHEATSHEET.md"
if [[ -f "$CHEAT_SRC" ]]; then
  backup_if_exists "$CHEAT_DST"
  cp "$CHEAT_SRC" "$CHEAT_DST"
  ok "CHEATSHEET.md copiado"
fi

# ═════════════════════════════════════════════════════════
# 12. CHECAGEM SUAVE DE DEPENDÊNCIAS
# ═════════════════════════════════════════════════════════
echo ""; echo "${YELLOW}--- Dependências ---${NC}"
if command -v npx >/dev/null 2>&1; then ok "node/npx"; else warn "npx ausente (MCPs npm) — instale Node.js"; fi
if command -v docker >/dev/null 2>&1; then ok "docker"; else warn "docker ausente (MCP terraform)"; fi
if command -v uvx >/dev/null 2>&1; then ok "uvx"; else warn "uvx ausente (MCP aws) — instale uv: https://docs.astral.sh/uv/"; fi

# ═════════════════════════════════════════════════════════
# 13. RESUMO
# ═════════════════════════════════════════════════════════
echo ""
echo "${GREEN}╔══════════════════════════════════════╗${NC}"
echo "${GREEN}║           Setup concluído!           ║${NC}"
echo "${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""
echo "  Escopo:       $SCOPE"
echo "  Destino:      $TARGET"
echo "  Config:       $CONFIG_FILE"
echo "  Agentes:      ${agents_sel[*]}"
echo "  Default:      $default_agent"
echo "  Container:    $CONTAINER_ORCH"
echo "  Skills:       ${installed_skills[*]:-nenhuma}"
echo "  Commands:     ${installed_commands[*]:-nenhum}"
echo "  References:   ${USE_REFS}"
echo "  Plugin:       validate-naming"
echo "  Modelos:      planner=$MODEL_PLANNER | executor=$MODEL_EXECUTOR | reviewer=$MODEL_REVIEWER"
echo ""
echo "${YELLOW}Dica:${NC} se o modelo der erro ou carregar outro, confirme os IDs com: ${GREEN}opencode models opencode${NC}"
echo ""
echo "${YELLOW}Próximo passo:${NC} leia $COMECE"
echo ""
