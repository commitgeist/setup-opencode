#!/usr/bin/env bats
# Testes do setup-opencode — rode com: bats tests/

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  TMP="$(mktemp -d)"
  cd "$TMP"
}

teardown() {
  rm -rf "$TMP"
}

run_setup() {
  run bash "$REPO_DIR/setup.sh" --answers "$REPO_DIR/tests/fixtures/answers.env"
}

@test "setup roda sem erro em modo não-interativo" {
  run_setup
  [ "$status" -eq 0 ]
}

@test "gera opencode.json válido (jq empty)" {
  run_setup
  [ -f opencode.json ]
  run jq empty opencode.json
  [ "$status" -eq 0 ]
}

@test "default_agent é um primary" {
  run_setup
  da="$(jq -r .default_agent opencode.json)"
  [ "$da" = "architect" ]
}

@test "MCPs condicionais: aws e azure-devops presentes, org correta" {
  run_setup
  [ "$(jq -r '.mcp.aws.enabled' opencode.json)" = "true" ]
  run jq -e '.mcp["azure-devops"].command | index("testorg")' opencode.json
  [ "$status" -eq 0 ]
}

@test "agents instalados com modelo substituído (sem placeholder)" {
  run_setup
  [ -f .opencode/agents/architect.md ]
  [ -f .opencode/agents/devops-engineer.md ]
  [ -f .opencode/agents/developer.md ]
  [ -f .opencode/agents/reviewer.md ]
  grep -q "model: opencode/kimi-k2.5-free" .opencode/agents/architect.md
  ! grep -q "{{MODEL}}" .opencode/agents/architect.md
}

@test "skills condicionais pela stack" {
  run_setup
  [ -d .opencode/skills/terraform-aws ]      # AWS + Terraform
  [ -d .opencode/skills/ecs-deploy ]          # AWS
  [ -d .opencode/skills/k8s-manifest-gitops ] # USE_K8S=Sim
  [ -d .opencode/skills/azure-pipelines-oidc ] # AzPipelines + AWS
  [ -d .opencode/skills/postgres-dba ]        # PostgreSQL
}

@test "scripts das skills são executáveis" {
  run_setup
  [ -x .opencode/skills/terraform-aws/scripts/validate.sh ]
  [ -x .opencode/skills/ecs-deploy/scripts/validate-service.sh ]
}

@test "commands instalados" {
  run_setup
  [ -f .opencode/commands/new-adr.md ]
  [ -f .opencode/commands/validate-all.md ]
}

@test "docs/adr e COMECE-AQUI gerados, com modelos substituídos" {
  run_setup
  [ -f docs/adr/TEMPLATE.md ]
  [ -f COMECE-AQUI.md ]
  grep -q "opencode/kimi-k2.5-free" COMECE-AQUI.md
  ! grep -q "{{M_PLANNER}}" COMECE-AQUI.md
}

@test "COMECE-AQUI contém conteúdo educacional (ecossistema e níveis)" {
  run_setup
  grep -q "Tool vs MCP vs Skill vs Agente" COMECE-AQUI.md
  grep -q "Platina" COMECE-AQUI.md
  grep -q "O que é ADR" COMECE-AQUI.md
}

@test "CHEATSHEET.md copiado" {
  run_setup
  [ -f CHEATSHEET.md ]
  grep -q "Cheatsheet" CHEATSHEET.md
}

@test "idempotência: segunda execução preserva backup" {
  run_setup
  [ "$status" -eq 0 ]
  sleep 1
  run_setup
  [ "$status" -eq 0 ]
  ls opencode.json.bak.* >/dev/null
  ls AGENTS.md.bak.* >/dev/null
}
