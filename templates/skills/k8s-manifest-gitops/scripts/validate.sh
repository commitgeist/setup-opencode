#!/usr/bin/env bash
# Validação de manifests K8s — uso: validate.sh [dir-ou-arquivo]
set -euo pipefail

TARGET="${1:-.}"
missing=()

echo "→ checando placeholders não substituídos"
if grep -rn "__[A-Z_]*__" "$TARGET" --include="*.yaml" --include="*.yml" 2>/dev/null; then
  echo "✗ placeholders __XXX__ ainda presentes — substitua todos"
  exit 1
fi

echo "→ checando :latest"
if grep -rn "image:.*:latest" "$TARGET" --include="*.yaml" --include="*.yml" 2>/dev/null; then
  echo "✗ tag :latest encontrada — use tag exata ou SHA"
  exit 1
fi

if command -v kube-linter >/dev/null 2>&1; then
  echo "→ kube-linter"
  kube-linter lint "$TARGET"
else
  missing+=("kube-linter")
fi

if command -v kubeconform >/dev/null 2>&1; then
  echo "→ kubeconform (schema)"
  find "$TARGET" \( -name "*.yaml" -o -name "*.yml" \) -exec kubeconform -summary {} +
else
  missing+=("kubeconform")
fi

if (( ${#missing[@]} > 0 )); then
  echo "⚠ ferramentas ausentes (puladas): ${missing[*]}"
fi

echo "✓ Validação passou"
