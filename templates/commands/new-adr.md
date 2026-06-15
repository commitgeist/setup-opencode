---
description: Criar novo ADR com numeração sequencial a partir do template
---

Você vai criar um novo ADR. Siga EXATAMENTE estes passos:

1. Liste os arquivos `docs/adr/[0-9]*.md` e identifique o maior número
   existente. O novo número é o maior + 1, formatado com 4 dígitos e
   zeros à esquerda (se não houver nenhum, comece em 0001).
2. Pergunte ao usuário o título do ADR (se ele já não informou).
3. Converta o título para slug kebab-case minúsculo sem acentos
   (ex: "Migração App CDN" → "migracao-app-cdn").
4. Copie `docs/adr/TEMPLATE.md` para `docs/adr/<NNNN>-<slug>.md`.
5. No novo arquivo, substitua "ADR-NNNN" pelo número real e o título.
6. Preencha o Status com `Proposed | <data de hoje em YYYY-MM-DD>`.
7. Informe o path criado e PARE. Não preencha nenhuma outra seção —
   isso é trabalho do architect com contexto da tarefa.
