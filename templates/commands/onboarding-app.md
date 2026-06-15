---
description: Discovery técnico de uma app recém-clonada para preparar CI/CD
---

Você vai fazer o discovery técnico de uma aplicação para preparar o
CI/CD dela. NÃO modifique nada — apenas investigue e relate.

Investigue, nesta ordem:

1. **Stack**: linguagem e versão (procure .csproj, package.json, go.mod,
   pom.xml, requirements.txt, Dockerfile existente)
2. **Framework**: ASP.NET, Express, Spring, etc.
3. **Build**: como compila (README, Makefile, scripts, CI existente)
4. **Run**: comando para rodar local
5. **Porta(s)**: onde a app escuta (procure configurações de porta,
   launchSettings.json, app.listen, server.port)
6. **Health endpoint**: procure por /health, /healthz, /ready, /ping
7. **Variáveis de ambiente**: procure GetEnvironmentVariable,
   process.env, os.Getenv, os.environ
8. **Secrets prováveis**: connection strings, API keys referenciadas
9. **Dependências externas**: bancos, caches, filas, APIs
10. **Estado**: escreve em disco? sessão em memória? (afeta réplicas)
11. **Migrações**: migrations/, flyway, EF, alembic

Gere o relatório em `docs/devops/onboarding.md` com uma seção por item.
Marque com ❓ TUDO que não conseguiu inferir do código — essas são as
perguntas a levar para o time de dev.

Termine listando as perguntas ❓ em bloco separado, prontas para
copiar e colar no chat com os devs.
