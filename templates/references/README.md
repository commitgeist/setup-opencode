# References — Configs de Referência

> Este diretório contém **arquivos reais** do seu ambiente, usados como
> "fonte da verdade" pelos agentes ao criar novos arquivos de infra.

## Como usar

1. **Cole aqui** um arquivo real que funciona no seu ambiente
2. O agente **lê este diretório** antes de criar novos arquivos
3. Ele **copia a estrutura** e adapta apenas os valores específicos

## Estrutura esperada

```
references/
├── pipeline/           ← .azure-pipelines.yaml real de um projeto
│   └── .azure-pipelines.yaml
├── k8s-manifests/      ← manifests reais (se usar AKS)
│   ├── deployment-exemplo.yaml
│   ├── service-exemplo.yaml
│   └── ingress-exemplo.yaml
├── ecs/                ← task-definition e service reais (se usar ECS)
│   ├── task-definition-exemplo.json
│   └── service-exemplo.json
└── README.md           ← este arquivo
```

## Regras para o agente

- **SE** existe um reference para o tipo de arquivo que vai criar → **USE como base**
- **SE** o reference estiver vazio (só .gitkeep) → use o template da skill
- **NUNCA** invente padrões quando existe um reference disponível
- **NUNCA** mude a estrutura do reference sem aprovação explícita do humano

## Dicas

- Não precisa ser o arquivo completo — pode ser um "exemplo canônico" com
  as partes que você quer que sejam padrão
- Remova secrets/valores sensíveis antes de colar aqui
- Um arquivo por tipo é suficiente (o agente extrai o padrão a partir dele)
- Atualize quando seu padrão evoluir

## O que NÃO colocar aqui

- Secrets, tokens, senhas (mesmo de dev)
- Arquivos de 500+ linhas sem curadoria (crie uma versão enxuta)
- Configs deprecated que você não quer mais replicar
