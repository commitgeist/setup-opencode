# Cheatsheet — OpenCode + Agentes

## Como funciona a configuração

As configurações são carregadas em camadas:

```
~/.config/opencode/opencode.jsonc   ← GLOBAL (todo repo)
~/.config/opencode/AGENTS.md        ← GLOBAL (todo repo)
  + opencode.json                   ← LOCAL (só este repo)
  + AGENTS.md                       ← LOCAL (só este repo, sobrescreve o global)
```

**Agentes e MCPs definidos no global** ficam disponíveis em QUALQUER repo.
**Agentes e MCPs definidos no local** valem só pra aquele repo.

> O local sempre sobrescreve o global nos mesmos campos.

---

## Chamando agentes

No chat, use `@nome-do-agente`:

```
@devops-engineer "implemente o ADR 0001"
@reviewer "valide contra docs/adr/0001-*.md"
@suporte "verifique os pods do namespace myapp"
```

- `Tab` alterna entre primary agents
- `@` lista subagents disponíveis
- `/` lista commands instalados

---

## Exemplos de agentes por área

### ☁️ CloudOps (AWS + Azure + Kubernetes)

| Agente | Descrição |
|---|---|
| `@devops-engineer` | Opera infra multi-cloud: Terraform, K8s, pipelines, networking |
| `@architect` | Planeja mudanças e gera ADRs — nunca implementa diretamente |
| `@reviewer` | Valida implementação contra padrões e ADRs (read-only) |

### 🗄️ Database

| Agente | Descrição |
|---|---|
| `@dba` | PostgreSQL, SQL Server: queries, índices, performance, backup |

### 🖥️ Suporte

| Agente | Descrição |
|---|---|
| `@suporte` | Diagnóstico read-only de incidentes: logs, métricas, status |

### 🔐 Segurança

| Agente | Descrição |
|---|---|
| `@secops` | Postura de segurança: IAM, network policies, encryption |

> Quer mais agentes? Veja `docs/ENRIQUECER-SETUP.md` para criar novos.

---

## Como criar seu próprio agente

Adicione no `opencode.json` (local) ou `~/.config/opencode/opencode.jsonc` (global):

```jsonc
"agent": {
  "meu-agente": {
    "description": "Descrição curta do papel",
    "mode": "primary",
    "model": "anthropic/claude-sonnet-4-6",
    "temperature": 0.2,
    "tools": { "write": true, "edit": true, "bash": true }
  }
}
```

### Dicas de configuração

- **`temperature`**: `0.1` para tarefas precisas (DBA, revisão), `0.3` para planejamento
- **`mode`**: `"primary"` (independente, usa Tab), `"subagent"` (chamado por outro via @)
- **`permission`**: restrinja ações destrutivas com `"ask"` ou `"deny"`
- **`model`**: use modelos diferentes por papel (forte pro architect, leve pro reviewer)

### Restringindo permissões

```jsonc
"permission": {
  "bash": {
    "kubectl delete*": "deny",
    "terraform destroy*": "deny",
    "terraform apply*": "ask",
    "git push*": "ask",
    "*": "allow"
  }
}
```

---

## Fluxo completo (ADR → Implementação → Review)

```
1. architect:       "Planeje <mudança>"           → gera docs/adr/NNNN-titulo.md
2. HUMANO:          revisa e aprova o ADR          (gate obrigatório)
3. devops-engineer: "Implemente docs/adr/NNNN-*"  → executa passo a passo
4. @reviewer:       "Valide contra o ADR"          → aponta desvios
5. HUMANO:          abre PR
```

---

## Dicas rápidas

- **Plan mode** (Tab) antes de Build mode para análises read-only
- **Skills** carregam contexto sob demanda — são o manual do agente
- **Scripts de validação** nas skills rodam checagens automatizadas
- **Commands** (`/new-adr`, `/validate-all`) são atalhos para workflows comuns
- **Secrets**: Key Vault / Variable Groups — nunca hardcode
- **Pin versões**: `~> X.Y` em providers, SHA em imagens, nunca `:latest`
- **Validação sempre**: `terraform plan`, `kubectl diff`, `tflint`, `checkov`
- **Modelo free se perde?** Use prompts curtos, um passo por vez, siga os checkpoints das skills
