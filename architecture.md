# 🏗 Arquitetura do Sistema

## Visão Macro

```
┌─────────────────────────────────────────────────────────────────────┐
│                           USUÁRIO FINAL                              │
│                    (Funcionário via WhatsApp)                        │
└─────────────────────────────┬───────────────────────────────────────┘
                              │ Mensagem de texto
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        EVOLUTION API                                 │
│              Gateway WhatsApp (protocolo Baileys)                    │
│                                                                      │
│  • Mantém sessão WhatsApp autenticada                                │
│  • Converte mensagens para JSON                                      │
│  • Dispara webhooks para N8N                                         │
│  • Envia respostas formatadas                                        │
└─────────────────────────────┬───────────────────────────────────────┘
                              │ Webhook POST (JSON)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                             N8N                                      │
│                   Orquestrador de Workflows                          │
│                                                                      │
│  Nó 1: Parse & Validação ──────────────────────────────────────┐    │
│    • Extrai telefone, mensagem, metadados                       │    │
│    • Normaliza número (remove formatação)                       │    │
│                                                                 │    │
│  Nó 2: Validação de Segurança                                  │    │
│    • Bloqueia grupos (@g.us)                                   │    │
│    • Bloqueia mensagens do bot (fromMe: true)                  │    │
│    • Valida comprimento do telefone                            │    │
│                                                                 │    │
│  Nó 3: GLPI Init Session ──► Buscar Usuário ──► Processar      │    │
│    • Autentica na API REST do GLPI                             │    │
│    • Busca por campo mobile/phone                              │    │
│    • Verifica se usuário está ativo                            │    │
│                                                                 │    │
│  Nó 4: Ollama IA ─────────────────────────────────────────┐   │    │
│    • Envia mensagem + system prompt com formulários         │   │    │
│    • Recebe JSON com formulário sugerido                    │   │    │
│    • Processa resposta (fallback para menu se falhar)       │   │    │
│                                                             │   │    │
│  Nó 5: Decisão ─────────────────────────────────────────┐  │   │    │
│    • needsTicket: false → Responde com sugestão         │  │   │    │
│    • needsTicket: true  → Cria ticket no GLPI           │  │   │    │
│                                                          │  │   │    │
│  Nó 6: GLPI Init Session ──► POST /Ticket ──► Kill      │  │   │    │
│                                                          │  │   │    │
│  Nó 7: Evolution API → Envia resposta ao usuário        │  │   │    │
└─────────────────────────────────────────────────────────────────────┘
              │                               │
              ▼                               ▼
┌──────────────────────┐         ┌────────────────────────┐
│       OLLAMA          │         │       GLPI API          │
│   IA Local (8B)       │         │   REST API             │
│                       │         │                        │
│  • glpi-assistant     │         │  • /initSession        │
│  • Classifica         │         │  • /search/User        │
│    linguagem natural  │         │  • /Ticket (POST)      │
│  • Sugere formulário  │         │  • /killSession        │
│  • Retorna JSON       │         │                        │
└──────────────────────┘         └────────────────────────┘
```

---

## Modelo de Dados

### Estado da Conversa (N8N em memória)

```javascript
{
  phone: "DDDNUMERO",         // Telefone normalizado
  message: "texto da mensagem", // Mensagem do usuário
  metadata: {
    isGroup: false,             // É mensagem de grupo?
    fromMe: false,              // É mensagem enviada pelo bot?
    remoteJid: "55DDDNUMERO@s.whatsapp.net",
    pushName: "Nome do Usuário"
  }
}
```

### Resposta da IA (Ollama)

```json
{
  "resposta": "Texto formatado com emojis para o WhatsApp",
  "formulario_id": 17,
  "formulario_nome": "Computador lento",
  "category_id": 10,
  "needsTicket": false,
  "confianca": 0.95
}
```

### Payload para GLPI (POST /Ticket)

```json
{
  "input": {
    "name": "Título do chamado",
    "content": "<p>Descrição com informações do solicitante</p>",
    "itilcategories_id": 10,
    "urgency": 3,
    "impact": 3,
    "priority": 3,
    "type": 1,
    "status": 2,
    "_users_id_requester": 13
  }
}
```

---

## Segurança

### Camadas de Validação

1. **Nível de mensagem:** Bloqueia grupos e mensagens enviadas pelo bot
2. **Nível de usuário:** Somente números cadastrados no GLPI são atendidos
3. **Nível de API:** Tokens GLPI com permissão mínima necessária
4. **Nível de rede:** Evolution API e N8N em rede Docker isolada

### Boas Práticas Implementadas

- Tokens GLPI não ficam em código — apenas em variáveis de ambiente
- Usuário de banco com permissão de leitura apenas
- Sessões GLPI abertas e fechadas por requisição (sem sessão persistente)
- Logs não registram conteúdo de mensagens dos usuários

---

## Escalabilidade

### Pontos de Atenção

| Componente | Limitação | Solução para Escala |
|------------|-----------|---------------------|
| Ollama (CPU) | ~15s por requisição | Adicionar GPU ou usar API externa |
| N8N (1 instância) | Execuções sequenciais | N8N Queue Mode com workers |
| Evolution API | 1 número por instância | Múltiplas instâncias para múltiplos números |
| GLPI API | Rate limit implícito | Pool de sessões ou cache de tokens |

### Diagrama de Alta Disponibilidade (Futuro)

```
Load Balancer
    ├── Evolution API (instância 1)
    ├── Evolution API (instância 2)
    └── N8N Worker Pool
          ├── Worker 1 → Ollama GPU
          ├── Worker 2 → Ollama GPU
          └── Shared PostgreSQL (GLPI + N8N)
```
