# Plugins no OpenCode

## O que são plugins?

Plugins são scripts TypeScript que **interceptam ações do agente** em tempo
de execução. Diferente de skills (instruções de texto) ou AGENTS.md (regras
em linguagem natural), plugins atuam na camada de **execução** — podem
bloquear, modificar ou validar operações antes que aconteçam.

```
┌─────────────────────────────────────────────────────────────────┐
│  Camadas de controle do agente (do mais fraco ao mais forte)    │
├───────────────────┬─────────────────────────────────────────────┤
│  1. AGENTS.md     │ Instrução em linguagem natural (pode ignorar) │
│  2. Skills        │ Workflow passo a passo (pode pular passos)     │
│  3. Plugins ⚡    │ Código que BLOQUEIA a ação (não tem como pular)│
└───────────────────┴─────────────────────────────────────────────┘
```

## Por que usar plugins?

Modelos de linguagem (especialmente free) podem:
- Esquecer de seguir uma regra do AGENTS.md
- Pular um passo do workflow de uma skill
- Inventar nomes de arquivo fora do padrão

Um plugin **não depende da atenção do modelo** — ele intercepta a ação
e lança um erro se a regra for violada. O modelo é forçado a corrigir.

## Onde ficam?

```
.opencode/plugins/           ← escopo local (por-repo)
~/.config/opencode/plugins/  ← escopo global (todo projeto)
```

O OpenCode auto-descobre todos os arquivos `.ts` dentro desses diretórios.

## Ciclo de vida

```
┌──────────┐     ┌──────────────────┐     ┌──────────┐
│  Agente  │────▶│  Plugin (before) │────▶│   Tool   │
│  decide  │     │  valida/bloqueia │     │  executa │
└──────────┘     └──────────────────┘     └──────────┘
                         │
                         ▼ (se throw Error)
                  ┌──────────────┐
                  │ Agente recebe│
                  │ o erro e     │
                  │ CORRIGE      │
                  └──────────────┘
```

## Hooks disponíveis

| Hook | Quando executa | Uso típico |
|---|---|---|
| `tool.execute.before` | Antes de qualquer tool rodar | Validar nomes, bloquear ações |
| `tool.execute.after` | Após a tool rodar com sucesso | Logging, auditoria |

## Estrutura básica de um plugin

```typescript
export default async () => ({
  name: "meu-plugin",

  "tool.execute.before": async (input, output) => {
    // input.name = nome da tool ("write", "edit", "bash", etc)
    // output.args = argumentos que serão passados à tool
    
    if (/* condição de violação */) {
      throw new Error("Mensagem de erro que o agente vai ler");
    }
    // Se não lançar erro, a tool executa normalmente
  },

  "tool.execute.after": async (input, output) => {
    // output.result = resultado da tool
    console.log(`Tool ${input.name} executou com sucesso`);
  },
});
```

## Plugin instalado: validate-naming

Este setup instala o plugin `validate-naming` que valida naming conventions
antes de criar/editar arquivos. Ele intercepta as tools `write`, `edit` e
`create`.

### O que ele valida

| Regra | Exemplo correto | Bloqueado |
|---|---|---|
| Azure Pipelines: `.azure-pipelines.yaml` | `.azure-pipelines.yaml` | `azure-pipelines.yml` |
| K8s manifests: `<tipo>-<app>.yaml` | `deployment-api.yaml` | `deploy.yaml` |
| ECS task def: `task-definition-<app>.json` | `task-definition-api.json` | `taskdef.json` |
| Dockerfile: `Dockerfile` ou `Dockerfile.<var>` | `Dockerfile.migrations` | `dockerfile` |
| Shell: kebab-case | `deploy-prod.sh` | `deployProd.sh` |
| Extensão YAML (K8s/Azure): `.yaml` | `service-api.yaml` | `service-api.yml` |

### Isenções inteligentes

O plugin **NÃO** bloqueia `.yml` quando o path é:
- `.github/workflows/*.yml` (padrão obrigatório do GitHub Actions)
- `.gitlab-ci.yml` (padrão obrigatório do GitLab CI)
- `bitbucket-pipelines.yml` (padrão obrigatório do Bitbucket)

Cada CI/CD tem suas convenções e o plugin respeita todas.

### Como customizar

Edite `.opencode/plugins/validate-naming.ts`:

```typescript
// Adicionar nova regra
const NAMING_RULES: NamingRule[] = [
  // ...regras existentes...
  
  // Nova regra: Helm charts devem ser chart-<app>.yaml
  {
    match: /chart/i,
    mustMatch: /chart-[\w-]+\.yaml$/,
    errorMsg: "Helm chart deve seguir: `chart-<app>.yaml`",
    exclude: CI_CD_EXEMPT_PATHS,  // opcional
  },
];
```

### Como desabilitar temporariamente

Renomeie o arquivo:
```bash
mv .opencode/plugins/validate-naming.ts .opencode/plugins/validate-naming.ts.disabled
```

## Criando seu próprio plugin

### Exemplo: bloquear `kubectl apply` em produção

```typescript
export default async () => ({
  name: "block-kubectl-apply",

  "tool.execute.before": async (input, output) => {
    if (input.name !== "bash") return;
    
    const cmd = (output.args?.command ?? "") as string;
    
    if (/kubectl\s+(apply|patch|delete|edit)/.test(cmd)) {
      // Permite se for --dry-run ou diff
      if (/--dry-run|diff/.test(cmd)) return;
      
      throw new Error(
        "⛔ PROIBIDO: kubectl apply/patch/delete direto.\n" +
        "Use GitOps: commit no repo de manifests + ArgoCD sync."
      );
    }
  },
});
```

### Exemplo: forçar --dry-run em terraform apply

```typescript
export default async () => ({
  name: "terraform-safety",

  "tool.execute.before": async (input, output) => {
    if (input.name !== "bash") return;
    
    const cmd = (output.args?.command ?? "") as string;
    
    if (/terraform\s+apply/.test(cmd) && !/-auto-approve/.test(cmd)) {
      // OK — sem auto-approve o TF vai pedir confirmação
      return;
    }
    
    if (/terraform\s+apply.*-auto-approve/.test(cmd)) {
      throw new Error(
        "⛔ terraform apply -auto-approve bloqueado.\n" +
        "Use: terraform apply (sem -auto-approve) para revisar o plan."
      );
    }
  },
});
```

### Exemplo: auditar todas as escritas em arquivo

```typescript
export default async () => ({
  name: "audit-writes",

  "tool.execute.after": async (input, output) => {
    const writingTools = ["write", "edit", "create"];
    if (!writingTools.includes(input.name)) return;
    
    const filePath = output.args?.filePath ?? output.args?.path ?? "";
    const timestamp = new Date().toISOString();
    
    // Log simples — em produção poderia enviar pra um webhook
    console.log(`[AUDIT] ${timestamp} | ${input.name} | ${filePath}`);
  },
});
```

## Boas práticas

1. **Um plugin = uma responsabilidade** — não misture validação de naming
   com bloqueio de comandos no mesmo arquivo
2. **Mensagens de erro claras** — o agente lê o erro e precisa entender
   como corrigir. Inclua o padrão correto na mensagem.
3. **Isenções explícitas** — use `exclude` para paths que são exceção legítima
4. **Não exagere** — plugins demais tornam o agente lento. Use para regras
   que o modelo erra repetidamente, não para tudo.
5. **Teste localmente** — renomeie pra `.disabled` se algo quebrar

## Comparação com outras abordagens

| Abordagem | Força | Quando usar |
|---|---|---|
| AGENTS.md | 🟡 Média | Regras gerais, contexto do projeto |
| Skill workflow | 🟡 Média | Passo-a-passo complexo com checkpoints |
| Plugin (before) | 🔴 Forte | Regras invioláveis que não toleram desvio |
| Plugin (after) | 🟢 Fraca | Auditoria, logging, sem bloqueio |
| Reference files | 🟡 Média | "Faça igual a este exemplo real" |

## Troubleshooting

- **Plugin não carrega**: verifique se está em `.opencode/plugins/` (local)
  ou `~/.config/opencode/plugins/` (global) com extensão `.ts`
- **Erro de sintaxe**: o OpenCode ignora plugins com erro de parse — verifique
  o console
- **Regra muito restritiva**: adicione `exclude` com regex dos paths isentos
- **Plugin bloqueia algo legítimo**: adicione exceção ou renomeie pra `.disabled`
