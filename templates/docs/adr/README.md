# Architecture Decision Records (ADR)

Este diretório guarda as decisões arquiteturais propostas pelo `architect` agent
e implementadas pelo `devops-engineer` agent.

## Estrutura

```
docs/adr/
├── README.md              # este arquivo
├── TEMPLATE.md            # template a ser copiado para novos ADRs
└── NNNN-titulo-slug.md    # ADRs numerados
```

## Numeração

Sequencial, 4 dígitos com zeros à esquerda: `0001`, `0002`, ...

Slug em kebab-case minúsculo: `0007-app-cdn-migration.md`

## Ciclo de vida

```
┌──────────────┐    ┌──────────┐    ┌─────────────┐    ┌──────────┐
│  Proposed    ├───▶│ Approved ├───▶│ Implemented ├───▶│ Archived │
└──────────────┘    └──────────┘    └─────────────┘    └──────────┘
       ▲                                  │
       │                                  ▼
       │                            ┌──────────┐
       └────────────────────────────┤Superseded│
                                    └──────────┘
```

- **Proposed**: gerado pelo Architect, aguardando review humano
- **Approved**: review humano aprovou, pronto pra Engineer implementar
- **Implemented**: Engineer concluiu, validações passaram
- **Superseded**: substituído por um ADR mais novo (linkar no header)
- **Archived**: implementação revertida ou decisão abandonada

## Como o Architect deve usar

1. Lê o contexto via MCPs (read-only)
2. Pergunta ao humano informações faltantes
3. Copia `TEMPLATE.md`
4. Preenche todas as seções
5. Status inicial: `Proposed | <data>`

## Como o Engineer deve usar

1. Lê o ADR completo
2. Verifica que está em status `Approved`
3. Implementa na ordem especificada
4. Atualiza Status para `Implemented | <data>` ao concluir
5. Adiciona nota de implementação no final do ADR
