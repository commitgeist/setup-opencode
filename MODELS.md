# Guia de Modelos

Como escolher os modelos de cada papel nesta estação. Os IDs **mudam com o
tempo** — sempre confirme os atuais com:

```bash
opencode models                 # todos os providers
opencode models opencode        # só Zen (inclui os -free)
opencode models openrouter      # OpenRouter
```

> ⚠️ **Privacidade.** Modelos *free* de provider público (Zen `-free`,
> OpenRouter `:free`, etc.) podem usar seus dados para treino. **Não use com
> código sensível de cliente** — prefira Ollama local ou um provider pago.

---

## Presets do wizard (`MODEL_TIER`)

| Preset | Para quê |
|--------|----------|
| `free-zen` | 100% free no Zen (turbinado): Nemotron + DeepSeek V4 Flash + Groq no review |
| `multi-provider` | Mais força, ainda free: o3 + Qwen Coder 480B + Groq |
| `free-openrouter` | Free via OpenRouter |
| `free-ollama` | Local, 100% privado |
| `anthropic` / `openai` | Pago |
| `custom` | Você digita os IDs |

---

## Mapa por papel — melhores opções reais

### `MODEL_PLANNER` — Architect (raciocínio, planeja, escreve ADR)

```
opencode/nemotron-3-ultra-free               # free garantido (Zen)

# upgrade quando precisar de mais força
nvidia/nvidia/nemotron-3-ultra-550b-a55b     # o maior Nemotron disponível
nvidia/qwen/qwen3.5-397b-a17b                # Qwen enorme, forte em raciocínio
github-models/openai/o3                       # melhor raciocínio do GitHub Models
google/gemini-2.5-pro                         # Google, muito forte
```

### `MODEL_EXECUTOR` — Engineer (executa, bash, tools)

```
opencode/deepseek-v4-flash-free               # free garantido (Zen)

# alternativas fortes
nvidia/deepseek-ai/deepseek-v4-pro            # DeepSeek V4 Pro via Nvidia
groq/llama-3.3-70b-versatile                 # rápido + capaz
nvidia/qwen/qwen3-coder-480b-a35b-instruct    # especialista em código, enorme
github-models/mistral-ai/codestral-2501       # especialista em código
mistral/codestral-latest                      # idem
```

### `MODEL_REVIEWER` — Reviewer / Suporte (leve, rápido, read-only)

```
groq/llama-3.1-8b-instant                     # o mais rápido de todos

# leve mas capaz
opencode/north-mini-code-free                 # free garantido (Zen)
google/gemini-3.5-flash                       # Google, rápido
github-models/openai/gpt-4.1-nano             # nano = leve
mistral/mistral-small-latest                  # leve, bom
```

---

## Configurações prontas para `answers.env`

```bash
# Uso diário — 100% free (preset free-zen)
MODEL_PLANNER=opencode/nemotron-3-ultra-free
MODEL_EXECUTOR=opencode/deepseek-v4-flash-free
MODEL_REVIEWER=groq/llama-3.1-8b-instant       # Groq exige API key gratuita

# Mais força, ainda sem custo (preset multi-provider)
MODEL_PLANNER=github-models/openai/o3
MODEL_EXECUTOR=nvidia/qwen/qwen3-coder-480b-a35b-instruct
MODEL_REVIEWER=groq/llama-3.1-8b-instant
```

---

## Joias escondidas (poucos usam)

```
nvidia/nvidia/nemotron-3-ultra-550b-a55b     # Nemotron gigante, free no tier Nvidia
nvidia/moonshotai/kimi-k2.6                   # Kimi K2.6, forte em agentic
mistral/magistral-medium-latest               # Magistral Medium, foco em raciocínio
github-models/openai/o3                        # o3, raciocínio pesado, free via GitHub
github-models/xai/grok-3                       # Grok 3 via GitHub Models
```

---

## O que ignorar (não servem para agente de texto)

```
# Áudio / vídeo / imagem
nvidia/nvidia/magpie-tts-zeroshot
nvidia/black-forest-labs/flux_1-*
groq/whisper-large-v3
google/gemini-*-tts

# Embedding (não é LLM)
nvidia/baai/bge-m3
mistral/mistral-embed

# Safety guards (uso específico)
groq/meta-llama/llama-prompt-guard-*
```
