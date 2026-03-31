# 🔧 Guia de Troubleshooting

## Diagnóstico Rápido

### Verificar saúde de todos os serviços

```bash
# Status dos containers
docker compose ps

# Logs em tempo real
docker compose logs -f

# Logs por serviço
docker logs -f evolution-api
docker logs -f n8n
```

---

## Problemas Comuns

### 1. Bot lê mensagem mas não responde

**Diagnóstico:**
```bash
# 1. Verificar se Evolution API está enviando webhook
docker logs evolution-api | grep -i webhook

# 2. Verificar se N8N recebeu a execução
# Acesse: http://SEU_N8N:5678 > Executions
```

**Causas e soluções:**

| Causa | Solução |
|-------|---------|
| Webhook desconectado | Reconfigure: `POST /webhook/set/INSTANCIA` |
| Workflow N8N inativo | Ative o toggle em N8N > Workflows |
| Ollama travado | `docker restart ollama` ou aumente timeout para 90s |

---

### 2. Erro ao abrir chamado no GLPI

```bash
# Ver erro detalhado no N8N
# Executions > Clique na execução com erro > Nó HTTP Request
```

| Código HTTP | Causa | Solução |
|-------------|-------|---------|
| 400 | Dados inválidos (campo numérico recebeu texto) | Revise o JSON enviado ao GLPI |
| 401 | Token expirado | Gere novo token no perfil do usuário no GLPI |
| 403 | Sem permissão | Verifique permissões do usuário técnico no GLPI |
| 404 | Endpoint incorreto | Verifique a URL da API REST do GLPI |

---

### 3. Todas as mensagens falham na validação de segurança

**Sintoma:** Bot responde "Validação de Segurança Falhou" para toda mensagem.

**Diagnóstico — verifique o payload real no N8N:**
1. N8N > Executions > Última execução com falha
2. Clique no nó "Parse & Validação Avançada"
3. Veja o INPUT recebido

**O que checar:**

```json
{
  "key": {
    "remoteJid": "5511999999999@s.whatsapp.net",  ← Deve terminar em @s.whatsapp.net
    "fromMe": false   ← DEVE ser false para mensagens recebidas
  }
}
```

**Se `fromMe: true` para todas mensagens:**
```bash
# Evolution API está enviando eventos de mensagens enviadas
# Reconfigure o webhook para só receber MESSAGES_UPSERT:

curl -X POST http://localhost:8080/webhook/set/NOME_INSTANCIA \
  -H "apikey: SUA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "http://SEU_N8N:5678/webhook/whatsapp-glpi",
    "events": ["MESSAGES_UPSERT"]
  }'
```

---

### 4. Usuário sempre aparece como "não autorizado"

**Causa provável:** Telefone com formatação errada no banco GLPI.

```sql
-- Verifique o formato no banco
SELECT id, name, mobile, phone FROM glpi_users WHERE name = 'login_do_usuario';

-- O campo deve conter APENAS números
-- ✅ Correto: DDDNUMERO
-- ❌ Errado: (48) 99664-6843 ou +55 48 99664-6843

-- Corrigir:
UPDATE glpi_users SET mobile = 'DDDNUMERO' WHERE id = ID_DO_USUARIO;
```

---

### 5. Ollama timeout (modelo demora demais)

```bash
# Verificar se está rodando
curl http://localhost:11434/api/tags

# Manter modelo em memória (evita cold start)
curl http://localhost:11434/api/generate -X POST \
  -H "Content-Type: application/json" \
  -d '{"model":"glpi-assistant:latest","prompt":"warmup","keep_alive":-1}'

# Verificar recursos disponíveis
free -h && nvidia-smi 2>/dev/null || echo "Sem GPU"
```

**Requisitos mínimos para modelo 8B (Q4_K_M):**
- RAM: 8 GB disponíveis
- CPU: Multi-core recomendado
- GPU NVIDIA com CUDA: opcional, mas reduz tempo de 15s para 2s

**Alternativas se hardware for insuficiente:**
- Use modelo menor: `ollama pull llama3.2:3b`
- Reduza `max_tokens` no payload Ollama

---

### 6. WhatsApp desconecta com frequência

**Causas comuns:**
- IP do servidor mudou (dinâmico)
- Sessão expirada pelo WhatsApp (inatividade)
- Múltiplas conexões simultâneas

**Solução:**
```bash
# Reconectar via painel
# http://localhost:8080/manager > Instância > Connect

# Ou via API:
curl -X GET http://localhost:8080/instance/connect/NOME_INSTANCIA \
  -H "apikey: SUA_API_KEY"
# Escaneie o QR Code retornado
```

---

### 7. Webhook N8N retorna 404

**Verificar URL correta:**

| Modo | URL | Uso |
|------|-----|-----|
| Teste (1 chamada) | `/webhook-test/whatsapp-glpi` | Debug no canvas |
| Produção | `/webhook/whatsapp-glpi` | Uso real |

```bash
# Ativar modo produção: N8N > Workflow > Toggle Active

# Testar:
curl -X POST http://localhost:5678/webhook/whatsapp-glpi \
  -H "Content-Type: application/json" \
  -d '{
    "key": {"remoteJid": "5511999999999@s.whatsapp.net", "fromMe": false},
    "message": {"conversation": "menu"}
  }'
```

---

## Testes Manuais

### Testar fluxo completo via curl

```bash
# Substitua o número por um cadastrado no GLPI
curl -X POST http://localhost:5678/webhook/whatsapp-glpi \
  -H "Content-Type: application/json" \
  -d '{
    "key": {"remoteJid": "55DDDNUMERO@s.whatsapp.net", "fromMe": false},
    "message": {"conversation": "meu computador está lento"},
    "messageTimestamp": '"$(date +%s)"'
  }'
```

### Testar API do GLPI diretamente

```bash
# Iniciar sessão
SESSION=$(curl -s http://SEU_GLPI/apirest.php/initSession \
  -H "App-Token: SEU_APP_TOKEN" \
  -H "Authorization: user_token SEU_USER_TOKEN" | jq -r .session_token)

# Buscar usuário por telefone (field 6 = mobile)
curl -s "http://SEU_GLPI/apirest.php/search/User?criteria[0][field]=6&criteria[0][searchtype]=equals&criteria[0][value]=48999999999" \
  -H "App-Token: SEU_APP_TOKEN" \
  -H "Session-Token: $SESSION" | jq .

# Encerrar sessão
curl -X GET http://SEU_GLPI/apirest.php/killSession \
  -H "App-Token: SEU_APP_TOKEN" \
  -H "Session-Token: $SESSION"
```

---

## Checklist de Verificação Pós-Deploy

```bash
# 1. Containers rodando
docker compose ps | grep -E "Up|running"

# 2. Evolution API acessível
curl -s http://localhost:8080/instance/fetchInstances \
  -H "apikey: SUA_API_KEY" | jq '.[].connectionStatus'
# Esperado: "open"

# 3. N8N acessível e workflow ativo
curl -s http://localhost:5678/healthz
# Esperado: {"status":"ok"}

# 4. Ollama com modelo carregado
curl -s http://localhost:11434/api/tags | jq '.models[].name'
# Esperado: "glpi-assistant:latest"

# 5. GLPI API acessível
curl -s http://SEU_GLPI/apirest.php/ | jq .
# Esperado: objeto com endpoints disponíveis

# 6. Teste end-to-end
# Envie "menu" pelo WhatsApp e aguarde resposta
```
