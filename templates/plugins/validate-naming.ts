/**
 * Plugin: validate-naming
 *
 * Intercepta criação/edição de arquivos e valida naming conventions.
 * Auto-descoberto pelo OpenCode a partir de .opencode/plugins/
 *
 * Regras configuráveis via NAMING_RULES abaixo.
 *
 * IMPORTANTE: Este plugin respeita os padrões de CADA CI/CD:
 * - Azure Pipelines: `.azure-pipelines.yaml` (forçamos .yaml)
 * - GitHub Actions: `.github/workflows/*.yml` (padrão do GitHub)
 * - GitLab CI: `.gitlab-ci.yml` (padrão do GitLab)
 * - Bitbucket: `bitbucket-pipelines.yml` (padrão do Bitbucket)
 * - Jenkins: `Jenkinsfile` (sem extensão)
 *
 * A regra "nunca .yml" se aplica APENAS a manifests K8s e Azure Pipelines.
 */

interface NamingRule {
  /** Regex que identifica o TIPO de arquivo pelo path */
  match: RegExp;
  /** Regex que o path DEVE satisfazer */
  mustMatch: RegExp;
  /** Mensagem de erro explicando o padrão correto */
  errorMsg: string;
  /** Paths a IGNORAR (não aplicar esta regra se o path bater aqui) */
  exclude?: RegExp;
}

// ═══════════════════════════════════════════════════════
// PATHS ISENTOS — padrões de CI/CD que usam .yml por convenção
// ═══════════════════════════════════════════════════════
const CI_CD_EXEMPT_PATHS =
  /\.(github\/workflows|gitlab-ci)|bitbucket-pipelines|Jenkinsfile/;

// ═══════════════════════════════════════════════════════
// REGRAS DE NAMING — edite aqui para ajustar ao seu padrão
// ═══════════════════════════════════════════════════════
const NAMING_RULES: NamingRule[] = [
  // Pipeline Azure DevOps
  {
    match: /azure.?pipelines?/i,
    mustMatch: /\.azure-pipelines\.yaml$/,
    errorMsg:
      "Pipeline Azure DevOps deve ser `.azure-pipelines.yaml` (não .yml, não azure-pipelines.yml)",
  },
  // YAML extension — .yml proibido APENAS para K8s manifests e Azure Pipelines
  // GitHub Actions, GitLab, Bitbucket usam .yml por convenção e são ISENTOS
  {
    match: /\.(yml)$/i,
    mustMatch: /^$/, // impossível — sempre falha se matchou .yml
    errorMsg:
      "Use extensão `.yaml` (não `.yml`) para manifests K8s e pipelines Azure DevOps",
    exclude: CI_CD_EXEMPT_PATHS,
  },
  // K8s Deployment
  {
    match: /deployment/i,
    mustMatch: /deployment-[\w-]+\.yaml$/,
    errorMsg:
      "K8s Deployment deve seguir: `deployment-<app>.yaml` (ex: deployment-api.yaml)",
    exclude: CI_CD_EXEMPT_PATHS,
  },
  // K8s Service (não confundir com ECS service que pode ser .json)
  {
    match: /service.*\.yaml$/i,
    mustMatch: /service-[\w-]+\.yaml$/,
    errorMsg: "K8s Service deve seguir: `service-<app>.yaml`",
    exclude: CI_CD_EXEMPT_PATHS,
  },
  // ECS Service (.json)
  {
    match: /service.*\.json$/i,
    mustMatch: /service-[\w-]+\.json$/,
    errorMsg: "ECS Service deve seguir: `service-<app>.json`",
  },
  // K8s Ingress
  {
    match: /ingress/i,
    mustMatch: /ingress-[\w-]+\.yaml$/,
    errorMsg: "Ingress deve seguir: `ingress-<app>.yaml`",
    exclude: CI_CD_EXEMPT_PATHS,
  },
  // K8s HPA
  {
    match: /hpa/i,
    mustMatch: /hpa-[\w-]+\.yaml$/,
    errorMsg: "HPA deve seguir: `hpa-<app>.yaml`",
    exclude: CI_CD_EXEMPT_PATHS,
  },
  // K8s PDB
  {
    match: /pdb/i,
    mustMatch: /pdb-[\w-]+\.yaml$/,
    errorMsg: "PDB deve seguir: `pdb-<app>.yaml`",
    exclude: CI_CD_EXEMPT_PATHS,
  },
  // ECS Task Definition
  {
    match: /task.?def/i,
    mustMatch: /task-definition-[\w-]+\.json$/,
    errorMsg:
      "ECS Task Definition deve seguir: `task-definition-<app>.json`",
  },
  // Dockerfile
  {
    match: /dockerfile/i,
    mustMatch: /Dockerfile(\.\w+)?$/,
    errorMsg:
      "Dockerfile deve ser `Dockerfile` ou `Dockerfile.<variante>` (case-sensitive, sem extensão aleatória)",
  },
  // Shell scripts (kebab-case)
  {
    match: /\.sh$/,
    mustMatch: /[a-z0-9]+(-[a-z0-9]+)*\.sh$/,
    errorMsg: "Shell scripts devem usar kebab-case: `nome-do-script.sh`",
  },
];

// ═══════════════════════════════════════════════════════
// PLUGIN EXPORT
// ═══════════════════════════════════════════════════════
export default async () => ({
  name: "validate-naming",

  "tool.execute.before": async (
    input: { name: string },
    output: { args?: { filePath?: string; path?: string } }
  ) => {
    // Intercepta tools que criam/editam arquivos
    const writingTools = ["write", "edit", "create"];
    if (!writingTools.includes(input.name)) return;

    const filePath =
      (output.args?.filePath ?? output.args?.path ?? "") as string;
    if (!filePath) return;

    // Extrai apenas o nome do arquivo (sem diretório) para matching
    const fileName = filePath.split("/").pop() ?? "";

    for (const rule of NAMING_RULES) {
      // Se o path está na lista de exclusão, pula esta regra
      if (rule.exclude && rule.exclude.test(filePath)) continue;

      // O arquivo se encaixa nesse tipo?
      if (rule.match.test(fileName) || rule.match.test(filePath)) {
        // Segue o padrão exigido?
        if (
          !rule.mustMatch.test(fileName) &&
          !rule.mustMatch.test(filePath)
        ) {
          throw new Error(
            `⛔ NAMING VIOLATION: ${rule.errorMsg}\n` +
              `   Arquivo: ${filePath}\n` +
              `   Corrija o nome antes de prosseguir.`
          );
        }
      }
    }
  },
});
