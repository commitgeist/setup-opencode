/**
 * Plugin: enforce-workflow-order
 *
 * Garante que o agente executor siga a ordem OBRIGATÓRIA:
 *
 *   1. ADR existe e está Approved (ou tarefa confirmada pelo humano)
 *   2. Agente apresentou PLANO e aguardou confirmação
 *   3. Só então pode escrever/editar arquivos de infra
 *
 * Mecanismo: verifica se o arquivo sendo criado/editado tem um
 * comentário de rastreabilidade (ADR ref ou "Confirmed: <descrição>").
 * Se não tiver, bloqueia e instrui o agente a seguir o protocolo.
 *
 * NOTA: Este plugin é uma rede de segurança. O enforcement principal
 * vem do agent template (workflow mandatório). O plugin pega os casos
 * em que o modelo "esquece" de seguir o fluxo.
 */

// Paths de infra que EXIGEM rastreabilidade (ADR ou confirmação)
const INFRA_PATHS = /\.(yaml|tf|json)$/;
const INFRA_DIRS =
  /\/(manifests|k8s|kubernetes|terraform|infra|iac|ecs|argocd|pipelines?)\//i;

// Paths ISENTOS (docs, tests, scripts de validação)
const EXEMPT_PATHS =
  /\/(docs|tests?|__tests__|spec|\.opencode|node_modules|references)\//i;

// Arquivos SEMPRE isentos
const EXEMPT_FILES = /^(README|CHANGELOG|LICENSE|\.gitignore|\.gitkeep|package\.json|tsconfig)/i;

export default async () => ({
  name: "enforce-workflow-order",

  "tool.execute.before": async (
    input: { name: string },
    output: { args?: { filePath?: string; path?: string; content?: string } }
  ) => {
    // Só intercepta writes/creates (não edits — edits são incrementais)
    if (input.name !== "write" && input.name !== "create") return;

    const filePath =
      (output.args?.filePath ?? output.args?.path ?? "") as string;
    if (!filePath) return;

    const fileName = filePath.split("/").pop() ?? "";

    // Isenções
    if (EXEMPT_PATHS.test(filePath)) return;
    if (EXEMPT_FILES.test(fileName)) return;

    // Só valida arquivos de infra em diretórios de infra
    if (!INFRA_PATHS.test(fileName)) return;
    if (!INFRA_DIRS.test(filePath) && !filePath.includes(".azure-pipelines")) {
      return;
    }

    // Verifica se o conteúdo tem referência de rastreabilidade
    const content = (output.args?.content ?? "") as string;

    const hasAdrRef = /ADR[- ]?\d{4}|docs\/adr\/\d{4}/i.test(content);
    const hasConfirmation = /Confirmed:|Aprovado:|TASK[- ]?\d+/i.test(content);
    const hasTraceComment =
      /# (ADR|Ref|Task|Confirmed|Source):/i.test(content) ||
      /<!-- (ADR|Ref|Task|Confirmed|Source):/i.test(content);

    if (!hasAdrRef && !hasConfirmation && !hasTraceComment) {
      throw new Error(
        `⛔ WORKFLOW ORDER VIOLATION: Arquivo de infra sem rastreabilidade.\n` +
          `   Arquivo: ${filePath}\n\n` +
          `   PROTOCOLO OBRIGATÓRIO:\n` +
          `   1. Deve existir um ADR aprovado em docs/adr/ para esta mudança\n` +
          `   2. O arquivo deve conter um comentário de rastreabilidade:\n` +
          `      YAML: # ADR: docs/adr/NNNN-titulo.md\n` +
          `      JSON: (no campo _metadata ou comentário no início)\n` +
          `      TF:   # ADR: docs/adr/NNNN-titulo.md\n\n` +
          `   Se é uma tarefa simples sem ADR, adicione:\n` +
          `      # Confirmed: <descrição da tarefa aprovada pelo humano>\n\n` +
          `   Isso garante rastreabilidade de TODA mudança de infra.`
      );
    }
  },
});
