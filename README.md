# 🤖 GLPI Helpdesk Automation — WhatsApp + IA Local

> Plataforma de automação de helpdesk com dois canais integrados: **bot WhatsApp** (via N8N + Evolution API) e **assistente flutuante no GLPI** (plugin SIE Assistant). Ambos usam **Ollama + Llama** rodando localmente — $0 de API, dados 100% internos.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/Node.js-16%2B-green)](https://nodejs.org)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue)](https://docs.docker.com/compose/)
[![GLPI](https://img.shields.io/badge/GLPI-11.0%2B-orange)](https://glpi-project.org)

---

## 📋 Índice

- [Visão Geral](#-visão-geral)
- [Componentes](#-componentes)
- [Arquitetura](#-arquitetura)
- [Funcionalidades](#-funcionalidades)
- [Stack Tecnológico](#-stack-tecnológico)
- [Pré-requisitos](#-pré-requisitos)
- [Instalação](#-instalação)
- [Configuração](#-configuração)
- [Uso](#-uso)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Fluxo de Dados](#-fluxo-de-dados)
- [Troubleshooting](#-troubleshooting)
- [Contribuindo](#-contribuindo)

---

## 🎯 Visão Geral

Este projeto resolve um problema clássico de helpdesk de TI: solicitações chegam por múltiplos canais sem padronização, e os usuários não sabem qual formulário preencher. A solução automatiza o roteamento e a abertura de chamados por dois canais complementares, usando IA local para interpretar linguagem natural.

---

## 🧩 Componentes

### 1. Bot WhatsApp → GLPI (N8N + Evolution API)
O usuário envia mensagem no WhatsApp → IA classifica → ticket aberto automaticamente.

```
WhatsApp → Evolution API → N8N → Ollama → GLPI API → Ticket criado
```

### 2. SIE Assistant (Plugin GLPI)
Botão flutuante no GLPI → usuário descreve o problema → IA sugere o formulário certo → abre pré-preenchido.

```
Interface GLPI → Plugin → Ollama → Formulário pré-preenchido
```

O mesmo servidor **Ollama** serve os dois canais simultaneamente, sem custo adicional.

📄 Documentação completa do plugin: [docs/sie-assistant-plugin.md](docs/sie-assistant-plugin.md)

---

## 🏗 Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                     FLUXO PRINCIPAL                          │
│                                                              │
│  WhatsApp ──► Evolution API ──► N8N ──► Ollama (IA)         │
│                                   │                          │
│                                   ├──► GLPI API              │
│                                   │     └── Criar Ticket     │
│                                   │     └── Buscar Usuário   │
│                                   │                          │
│                                   └──► Evolution API         │
│                                         └── Resposta WA      │
└─────────────────────────────────────────────────────────────┘
```

### Serviços

| Serviço | Função | Porta |
|---------|--------|-------|
| **Evolution API** | Gateway WhatsApp (recebe/envia mensagens) | 8080 |
| **N8N** | Orquestrador de workflows (lógica do bot) | 5678 |
| **Ollama** | Modelo de IA local para classificação | 11434 |
| **GLPI** | Sistema de Help Desk (tickets) | 80/443 |
| **PostgreSQL** | Banco de dados (Evolution API / N8N) | 5432 |

---

## ✨ Funcionalidades

### Para o Usuário Final
- 💬 **Atendimento via WhatsApp** — canal familiar, sem apps adicionais
- 🤖 **Classificação automática** — IA entende linguagem natural e encontra o formulário certo
- 📋 **Menu interativo** — categorias organizadas para navegação fácil
- ✅ **Confirmação imediata** — recebe número do ticket e link para acompanhamento
- 🔔 **Notificações proativas** — recebe updates quando o técnico responde

### Para a Equipe de TI
- 🎫 **Tickets padronizados** — abertura automática com categoria, prioridade e dados do solicitante
- 🔍 **Validação de usuários** — somente funcionários cadastrados no GLPI podem abrir chamados
- 📊 **Rastreabilidade** — todo o histórico registrado no GLPI
- 🚫 **Filtros de segurança** — bloqueia mensagens de grupos e loops do próprio bot

### Fluxos Suportados
- Abertura de chamado com coleta de título, descrição e anexos
- Consulta de chamados abertos
- Adição de acompanhamento em chamados existentes
- Cancelamento de chamados
- Menu principal com categorias organizadas

---

## 🛠 Stack Tecnológico

| Tecnologia | Versão | Uso |
|------------|--------|-----|
| **Node.js** | 16+ | Runtime do bot standalone |
| **N8N** | Latest | Orquestrador de workflows |
| **Evolution API** | v2.x | Gateway WhatsApp (Baileys) |
| **Ollama** | Latest | IA local para classificação |
| **GLPI** | 10/11 | Sistema de tickets |
| **Docker Compose** | v2 | Orquestração de containers |
| **MariaDB/MySQL** | 10.6+ | Banco do GLPI |
| **PostgreSQL** | 15+ | Banco do N8N/Evolution |

**Modelo de IA:** Customizado sobre LLaMA 8B (Q4_K_M), treinado especificamente para classificação de formulários GLPI.

---

## 📦 Pré-requisitos

- Docker e Docker Compose instalados
- GLPI instalado e configurado com:
  - REST API habilitada (`Configurar > Geral > API`)
  - App Token gerado
  - User Token de um técnico com permissões de criação de tickets
- Servidor com mínimo **8 GB RAM** (para o modelo de IA)
- Número de WhatsApp disponível para o bot

---

## 🚀 Instalação

### 1. Clone o repositório

```bash
git clone https://github.com/seu-usuario/whatsapp-glpi-bot.git
cd whatsapp-glpi-bot
```

### 2. Configure as variáveis de ambiente

```bash
cp .env.example .env
nano .env
```

Preencha todas as variáveis conforme a seção [Configuração](#-configuração).

### 3. Suba os containers

```bash
docker compose up -d
```

### 4. Conecte o WhatsApp

```bash
# Verifique os logs da Evolution API para o QR Code
docker logs -f evolution-api
```

Acesse `http://localhost:8080/manager`, clique na instância e escaneie o QR Code.

### 5. Importe o workflow no N8N

1. Acesse `http://localhost:5678`
2. Vá em **Workflows > Import from File**
3. Selecione o arquivo `workflows/whatsapp-glpi-bot.json`
4. Ative o workflow (toggle verde)

### 6. Configure o webhook no Evolution API

```bash
curl -X POST http://localhost:8080/webhook/set/NOME_DA_INSTANCIA \
  -H "apikey: SUA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "http://SEU_N8N:5678/webhook/whatsapp-glpi",
    "events": ["MESSAGES_UPSERT"]
  }'
```

---

## ⚙️ Configuração

### Arquivo `.env`

```env
# ========================================
# EVOLUTION API
# ========================================
AUTHENTICATION_API_KEY=sua-chave-aqui

# ========================================
# N8N
# ========================================
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=senha-segura
WEBHOOK_URL=https://n8n.seudominio.com
GENERIC_TIMEZONE=America/Sao_Paulo

# ========================================
# GLPI
# ========================================
GLPI_URL=http://IP_DO_GLPI
# Gere estes tokens no GLPI (Configurar > Geral > API)
# GLPI_APP_TOKEN=
# GLPI_USER_TOKEN=

# ========================================
# OLLAMA
# ========================================
OLLAMA_URL=http://IP_DO_OLLAMA:11434
OLLAMA_MODEL=glpi-assistant:latest

# ========================================
# BANCO DE DADOS
# ========================================
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n
DB_POSTGRESDB_PASSWORD=senha-db
```

### Mapeamento de Categorias GLPI

Edite o arquivo `config/categories.json` para mapear os IDs das categorias do seu GLPI:

```json
{
  "categories": [
    { "id": 1, "name": "Acesso e Identidade", "emoji": "🔐" },
    { "id": 2, "name": "CFTV", "emoji": "📹" },
    { "id": 3, "name": "E-mail e Colaboração", "emoji": "📧" },
    { "id": 5, "name": "Impressora/Scanner", "emoji": "🖨" },
    { "id": 6, "name": "Rede e Conectividade", "emoji": "🌐" },
    { "id": 10, "name": "Suporte à Estação", "emoji": "🖥" }
  ]
}
```

**Como encontrar IDs de categorias no GLPI:**
1. Vá em `Configurar > Intitulados > Categorias de Chamados`
2. Clique na categoria desejada
3. O ID está na URL: `.../itilcategory.form.php?id=**35**`

### Mapeamento de Formulários

```json
{
  "forms": [
    { "id": 15, "name": "Reset de senha", "category_id": 1,
      "keywords": ["senha", "esqueci", "bloqueado", "desbloqueio"] },
    { "id": 8,  "name": "Sem acesso à internet", "category_id": 6,
      "keywords": ["internet", "sem rede", "cabo", "offline"] },
    { "id": 17, "name": "Computador lento", "category_id": 10,
      "keywords": ["lento", "travando", "lentidão", "não liga"] }
  ]
}
```

---

## 📖 Uso

### Comandos do Bot

| Comando | Ação |
|---------|------|
| `menu` ou `0` | Volta ao menu principal |
| `1` a `6` | Seleciona categoria do menu |
| `SIM` | Confirma abertura de ticket |
| `#status` | Verifica status do sistema |
| `#ajuda` | Exibe ajuda |

### Exemplo de Conversa

```
Usuário: "Meu computador está muito lento"

Bot: Entendo que seu computador está lento 🐢

     Encontrei o formulário ideal:
     📋 Computador lento (ID: 17)
     🔗 http://seuglpi/front/helpdesk.public.php?form=17

     Digite SIM para confirmar ou 0 para voltar ao menu.

Usuário: "SIM"

Bot: ✅ Ticket #104 criado com sucesso!

     📋 Número: #104
     📂 Categoria: Suporte à Estação
     🔥 Prioridade: 3/5

     🔗 Acompanhe: http://seuglpi/front/ticket.form.php?id=104

     _Você receberá atualizações por WhatsApp._
```

---

## 📁 Estrutura do Projeto

```
glpi-helpdesk-automation/
├── docker-compose.yml          # Orquestração dos serviços
├── .env.example                # Template de variáveis (sem credenciais)
├── .gitignore
├── README.md
│
├── workflows/
│   └── whatsapp-glpi-bot.json  # Workflow N8N exportado
│
├── plugin/                     # Plugin SIE Assistant (GLPI 11)
│   └── sieassistant/
│       ├── setup.php           # Instalação e hooks
│       ├── hook.php
│       ├── sieassistant.xml    # Manifest
│       ├── public/
│       │   ├── ui.css          # Estilos do botão flutuante
│       │   ├── ui.js           # Lógica + prefill client-side
│       │   └── icon.svg
│       └── ajax/
│           └── intent.php      # Endpoint → Ollama → form_id
│
├── config/
│   ├── categories.json         # Mapeamento categorias GLPI
│   └── forms.json              # Mapeamento formulários
│
├── bot-standalone/             # Versão Node.js sem N8N
│   ├── bot.js
│   ├── package.json
│   └── user_emails.json.example
│
├── scripts/
│   ├── backup.sh
│   └── test-workflow.sh
│
└── docs/
    ├── architecture.md
    ├── troubleshooting.md
    └── sie-assistant-plugin.md # Documentação do plugin
```

---

## 🔄 Fluxo de Dados

### Recebimento de Mensagem

```
1. Usuário envia mensagem no WhatsApp
2. Evolution API recebe via Baileys
3. Evolution API dispara webhook para N8N
4. N8N: Parse & validação do payload
   ├── Bloqueia mensagens de grupo
   ├── Bloqueia mensagens do próprio bot (fromMe)
   └── Valida formato do telefone
5. N8N: Busca usuário via GLPI REST API
   ├── Autorizado → continua fluxo
   └── Não autorizado → responde com aviso
6. N8N: Envia mensagem para Ollama (IA)
   ├── Ollama classifica a solicitação
   ├── Retorna JSON com formulário sugerido
   └── Fallback para menu principal se falhar
7. N8N: Decide se precisa criar ticket
   ├── Sim → Init Session GLPI → POST /Ticket → Kill Session
   └── Não → Responde com sugestão de formulário
8. N8N: Envia resposta via Evolution API
```

### Estrutura do Payload WhatsApp (Evolution API)

```json
{
  "key": {
    "remoteJid": "5511999999999@s.whatsapp.net",
    "fromMe": false
  },
  "message": {
    "conversation": "texto da mensagem"
  },
  "pushName": "Nome do Usuário",
  "messageTimestamp": 1234567890
}
```

### Resposta do Ollama (formato esperado)

```json
{
  "resposta": "Mensagem formatada para o usuário com emojis",
  "formulario_id": 17,
  "formulario_nome": "Computador lento",
  "category_id": 10,
  "needsTicket": false,
  "confianca": 0.95
}
```

---

## 🔧 Troubleshooting

### Bot não responde às mensagens

1. Verifique se a instância WhatsApp está conectada:
```bash
curl http://localhost:8080/instance/connectionState/NOME_INSTANCIA \
  -H "apikey: SUA_API_KEY"
# Esperado: {"state": "open"}
```

2. Verifique se o workflow N8N está ativo:
   - Acesse N8N > Workflows
   - Confirme que o toggle está **verde (Active)**

3. Verifique os logs do N8N:
```bash
docker logs -f n8n | grep -E "webhook|error|execution"
```

### Erro 401 na API do GLPI

Token expirado ou inválido. Gere novos tokens:
1. GLPI > Perfil do usuário técnico > API Token
2. Atualize `GLPI_USER_TOKEN` no `.env` ou nas credenciais do N8N
3. Reinicie: `docker restart n8n`

### Erro 404 no webhook

```bash
# Workflow provavelmente inativo
# Ative em: N8N > Workflow > Toggle Active
# Teste manualmente:
curl -X POST http://localhost:5678/webhook/whatsapp-glpi \
  -H "Content-Type: application/json" \
  -d '{"key":{"remoteJid":"5511999999999@s.whatsapp.net","fromMe":false},"message":{"conversation":"menu"}}'
```

### Ollama não responde (timeout)

```bash
# Verificar se está rodando
curl http://localhost:11434/api/tags

# Ver modelo carregado
curl http://localhost:11434/api/ps

# Manter modelo em memória
curl http://localhost:11434/api/generate -X POST \
  -d '{"model":"glpi-assistant:latest","prompt":"warmup","keep_alive":-1}'
```

### Usuário sempre "não autorizado"

Verifique o formato do telefone no GLPI:
```sql
-- O campo mobile deve conter apenas números, sem formatação
-- Correto: DDDNUMERO
-- Errado: (48) 9999-9999

SELECT id, name, mobile FROM glpi_users
WHERE name = 'login_do_usuario';
```

### Webhook retorna fromMe: true para todas mensagens

Problema de configuração no Evolution API — está enviando eventos de mensagens **enviadas** pelo bot. Corrija:

```bash
curl -X POST http://localhost:8080/webhook/set/NOME_INSTANCIA \
  -H "apikey: SUA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "http://SEU_N8N:5678/webhook/whatsapp-glpi",
    "events": ["MESSAGES_UPSERT"]
  }'
# Remova "SEND_MESSAGE" dos eventos se estiver presente
```

---

## 💾 Backup

```bash
# Backup manual completo
tar -czvf backup-bot-$(date +%F).tar.gz \
  .env \
  evolution_store/ \
  workflows/

# Exportar workflows do N8N
# N8N > Workflows > Export all as JSON
```

**O que fazer backup:**
- `.env` — contém todas as configurações
- `evolution_store/` — sessão WhatsApp (evita re-scan do QR Code)
- Workflows do N8N exportados como JSON
- Banco de dados do GLPI (já incluso no seu processo de backup existente)

---

## 🤝 Contribuindo



### Padrão de Commits

```
feat: nova funcionalidade
fix: correção de bug
docs: atualização de documentação
chore: manutenção/configuração
```

---

## 📄 Licença

MIT License — veja [LICENSE](LICENSE) para detalhes.

---

## 👤 Autor

**Fernando Nunes Coutinho**  
Analista de TI — Gestão de Projetos de Informática  
[LinkedIn]((https://www.linkedin.com/in/fernando-nunes-coutinho/)) · [GitHub][((https://github.com/master-crypto)
---

## 🙏 Tecnologias Utilizadas

- [Evolution API](https://github.com/EvolutionAPI/evolution-api) — Gateway WhatsApp
- [N8N](https://n8n.io) — Workflow automation
- [Ollama](https://ollama.com) — IA local
- [GLPI](https://glpi-project.org) — Help Desk
- [@whiskeysockets/baileys](https://github.com/WhiskeySockets/Baileys) — WhatsApp Web API
