# Enriquecer o setup-opencode2.0

Guia pratico para evoluir o setup sem perder padrao, seguranca e previsibilidade.

## Objetivo

Quando voce quiser adicionar capacidade nova ao setup (novo agente, skill, command, opcao no wizard), siga este fluxo:

1. Primeiro define comportamento e guardrails.
2. Depois cria templates versionados.
3. Por ultimo conecta no `setup.sh` + `answers.env.example` + testes.

A regra principal: o script instala e valida. O conhecimento fica em templates.

## Mapa de extensao

- `templates/agents/*.md.tpl`: papeis com permissoes e modelo.
- `templates/skills/<nome>/`: conhecimento de dominio (SKILL + scripts + templates).
- `templates/commands/*.md`: atalhos de operacao.
- `templates/docs/adr/`: governanca de decisao.
- `setup.sh`: pergunta, decide condicoes e copia arquivos.
- `answers.env.example`: defaults para modo nao-interativo.
- `tests/setup.bats`: garante que a mudanca nao quebrou setup existente.

## 1) Adicionar um novo agente

Exemplo: `secops`.

1. Criar template em `templates/agents/secops.md.tpl`.
2. Usar placeholder `{{MODEL}}` no frontmatter.
3. Definir papel claro e limites de execucao.
4. No `setup.sh`:
   - incluir o agente no multiselect de `AGENTS`.
   - incluir no loop de instalacao (`install_agent`).
   - mapear modelo apropriado (forte vs leve).
5. Em `tests/setup.bats`:
   - validar que o arquivo foi instalado.
   - validar que `{{MODEL}}` foi substituido.

Checklist minimo:

- [ ] Template criado
- [ ] Instalacao no script conectada
- [ ] Cobertura em teste adicionada
- [ ] README atualizado

## 2) Adicionar uma nova skill

Exemplo: `helm-release`.

Estrutura recomendada:

```
templates/skills/helm-release/
├── SKILL.md
├── scripts/
│   └── validate.sh
└── templates/
    └── values.yaml
```

Passos:

1. Criar `SKILL.md` com:
   - quando usar
   - quando nao usar
   - entradas esperadas
   - fluxo passo a passo
2. Criar scripts de validacao (se fizer sentido) e marcar executavel.
3. No `setup.sh`, definir condicoes para copiar skill (stack-driven).
4. Em `tests/setup.bats`, validar existencia da skill quando condicao for verdadeira.

Boas praticas:

- Evite skills gigantes e genericas.
- Uma skill = um dominio bem definido.
- Se houver script, ele precisa falhar com codigo != 0 quando detectar erro.

## 3) Adicionar um novo command

Exemplo: `/incident-quickcheck`.

1. Criar `templates/commands/incident-quickcheck.md`.
2. No `setup.sh`, garantir copia para `.opencode/commands` (ou equivalente global).
3. Em `tests/setup.bats`, validar que o arquivo existe apos setup.
4. Documentar no README quando usar esse command.

## 4) Adicionar nova opcao no wizard

Exemplo: nova escolha de banco ou cloud.

1. Atualizar perguntas em `setup.sh` (`pick` ou `multiselect`).
2. Atualizar logica condicional de instalacao de agentes/skills/MCP.
3. Atualizar `answers.env.example` com default da nova variavel.
4. Atualizar `tests/fixtures/answers.env` para cobrir o caminho.
5. Ajustar testes para checar saida esperada.

## 5) Guardrails e seguranca

Regras para manter consistencia com o projeto:

1. Bloqueio real vai em permission/config, nao so em prompt.
2. Comandos destrutivos ficam `deny` por padrao.
3. Acoes sensiveis ficam `ask` (ex.: apply).
4. Sem segredo hardcoded em templates.
5. Sem `:latest` em imagens de exemplo.

## 6) Pipeline e qualidade

Toda evolucao do setup deve passar nesses checks:

```bash
bash -n setup.sh
shellcheck setup.sh templates/skills/*/scripts/*.sh
bats tests/
```

CI (`azure-pipelines.yml`) ja esta preparado para esse fluxo.

## 7) Definicao de pronto para uma extensao

Considere a extensao pronta quando:

1. Funciona no modo interativo.
2. Funciona no modo `--answers`.
3. Gera `opencode.json` valido (`jq empty`).
4. Tem teste automatizado cobrindo o caminho novo.
5. Esta documentada no README.

## 8) Estrategia de evolucao sem quebrar usuarios

1. Adicione capacidades de forma opcional por condicao de stack.
2. Preserve compatibilidade de variaveis em `answers.env.example`.
3. Quando renomear algo, mantenha alias por um ciclo (se possivel).
4. Sempre gerar backup de arquivos sobrescritos (`*.bak.<timestamp>`).

## 9) Fluxo sugerido para contribuidor

```bash
# 1) branch de feature
git checkout -b feat/setup-add-<recurso>

# 2) implementa template + setup + testes

# 3) valida local
bash -n setup.sh
shellcheck setup.sh templates/skills/*/scripts/*.sh
bats tests/

# 4) abre PR com:
# - objetivo
# - condicoes de instalacao
# - impacto em compatibilidade
# - evidencias de teste
```

## 10) Decisao de arquitetura (resumo)

- Pasta canonica: `setup-opencode2.0/`
- Pasta `setup-opencode/`: legado/read-only para referencia
- Toda nova feature entra apenas na 2.0
