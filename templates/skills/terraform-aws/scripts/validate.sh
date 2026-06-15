#!/usr/bin/env bash
# Validação Terraform — uso: validate.sh [diretório]
set -euo pipefail

DIR="${1:-.}"
cd "$DIR"

step() { echo "→ $*"; }
missing=()

step "terraform fmt (check)"
terraform fmt -recursive -check || { echo "✗ rode: terraform fmt -recursive"; exit 1; }

step "terraform validate"
terraform init -backend=false -input=false >/dev/null
terraform validate

if command -v tflint >/dev/null 2>&1; then
  step "tflint"
  tflint --recursive
else
  missing+=("tflint")
fi

if command -v checkov >/dev/null 2>&1; then
  step "checkov"
  checkov -d . --framework terraform --quiet --compact
else
  missing+=("checkov")
fi

if (( ${#missing[@]} > 0 )); then
  echo "⚠ ferramentas ausentes (puladas): ${missing[*]}"
fi

echo "✓ Todas validações passaram"
