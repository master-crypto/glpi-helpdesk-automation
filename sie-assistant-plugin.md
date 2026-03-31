# 🧩 SIE Assistant — Plugin GLPI com IA Local

> Assistente flutuante integrado ao GLPI 11 que usa **Llama 3.2 via Ollama** para interpretar linguagem natural, sugerir o formulário correto e abrir a solicitação pré-preenchida. **100% local, $0 de API.**

---

## Visão Geral

O **SIE Assistant** resolve um problema clássico de helpdesk: o usuário sabe o que precisa, mas não sabe qual formulário usar. Com um botão flutuante no GLPI, ele descreve o problema em linguagem natural e a IA encontra o formulário certo — automaticamente.

```
Usuário → Botão flutuante → Descreve o problema
       → POST /ajax/intent.php
       → Ollama (Llama 3.2 local)
       ← { form_id, confidence, prefill }
       → Formulário GLPI pré-preenchido
```

### Por que não usar a IA oficial do GLPI?

A IA nativa do GLPI 11 **resume tickets para técnicos** — não conversa com usuários nem roteia formulários. Este plugin preenche essa lacuna.

### Por que Ollama em vez de API de nuvem?

| | SIE + Ollama | OpenAI GPT-4 | Claude API |
|-|-------------|-------------|------------|
| **Custo/mês** | **$0** | $150-300 | $100-200 |
| **Dados** | 🟢 Internos | 🔴 Cloud | 🔴 Cloud |
| **Latência** | ~300ms | ~800ms | ~600ms |
| **Dependência** | Nenhuma | Internet | Internet |

---

## Arquitetura do Plugin

```
sieassistant/
  setup.php            # Instalação, hooks CSS/JS, config defaults
  hook.php             # Compatibilidade legacy
  sieassistant.xml     # Manifest do plugin
  public/
    ui.css             # Estilos do botão flutuante (FAB) e painel
    ui.js              # Lógica do assistente + prefill client-side
    icon.svg           # Ícone do FAB
  ajax/
    intent.php         # Endpoint: recebe texto → chama Ollama → retorna form_id
```

---

## Instalação

### Pré-requisitos

- GLPI **>= 11.0.0**
- PHP **>= 8.1**
- Ollama instalado e acessível

### 1. Instalar o Ollama

```bash
# Linux/Mac
curl -fsSL https://ollama.com/install.sh | sh

# Docker
docker run -d \
  -v ollama:/root/.ollama \
  -p 11434:11434 \
  --name ollama \
  ollama/ollama
```

### 2. Baixar o modelo

```bash
# Modelo principal (8B, ~5GB, melhor qualidade)
ollama pull llama3.2:7b

# Alternativa leve (3B, ~2GB, mais rápido)
ollama pull llama3.2:3b

# Verificar
ollama list
```

### 3. Instalar o plugin

```bash
# Copiar para o diretório de plugins do GLPI
cp -r sieassistant/ /var/www/html/glpi/plugins/

# No GLPI: Configurar > Plugins > Instalar > Ativar
```

O plugin cria a configuração padrão automaticamente:
- `ollama_url` → `http://localhost:11434`
- `ollama_model` → `llama3.2:7b`
- `timeout` → `15000` (ms)

---

## Configuração

### Via console do GLPI

```bash
php bin/console glpi:config:set plugin:sieassistant ollama_url http://localhost:11434
php bin/console glpi:config:set plugin:sieassistant ollama_model llama3.2:7b
php bin/console glpi:config:set plugin:sieassistant timeout 15000
```

### Personalizar formulários (`ajax/intent.php`)

Edite a tabela de referência para refletir os formulários do **seu** GLPI:

```php
$form_reference = <<<REF
TABELA DE FORMULÁRIOS GLPI:
- ID 37: Solicitação de acesso a sistemas (SAP, ERP, CRM)
- ID 42: Problemas de hardware (PC, impressora, monitor)
- ID 51: Problemas de software (Windows, Office, erros)
- ID 63: Problemas de rede (Wi-Fi, VPN, sem internet)
- ID 72: Reset de senha ou desbloqueio de usuário
REF;
```

> **Como encontrar IDs:** GLPI > Assistência > Formulários > (clique no formulário) > ID na URL

---

## Como o Pré-preenchimento Funciona

**Fluxo atual (client-side / MVP):**

```
1. Usuário digita: "preciso de acesso ao SAP"
2. IA retorna: { "form_id": 37, "prefill": { "sistema": "SAP" } }
3. Plugin monta URL: /form.form.php?id=37&sie_prefill=...
4. ui.js preenche campos por nome/id ou texto do label
```

Cobre 80–90% dos campos texto e select. Para 100% de cobertura, a evolução recomendada é migrar para pré-preenchimento server-side via GLPI HL API.

---

## Segurança

- **Autenticação obrigatória:** `intent.php` exige `Session::checkLoginUser()`
- **Dados 100% internos:** Llama roda localmente, nenhum dado sai do servidor
- **Sanitização:** campos `prefill` limitados a 500 chars e sanitizados
- **Compatível com LGPD:** sem transferência de dados pessoais para terceiros

### Recomendações adicionais

**Firewall — isolar a porta do Ollama:**
```bash
# Apenas rede interna acessa o Ollama
iptables -A INPUT -p tcp --dport 11434 -s 192.168.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport 11434 -j DROP
```

**Rate limiting (a implementar):**
```php
// Em intent.php — limitar 5 requisições/minuto por usuário
$user_id = Session::getLoginUserID();
// Implementar com APCu ou Redis
```

---

## Performance

### Se o Ollama estiver lento

```bash
# Opção 1: Verificar GPU NVIDIA (Ollama detecta automaticamente)
nvidia-smi

# Opção 2: Usar modelo menor
ollama pull llama3.2:3b
php bin/console glpi:config:set plugin:sieassistant ollama_model llama3.2:3b

# Opção 3: Aumentar threads de CPU
export OLLAMA_NUM_THREADS=8
```

### Manter modelo em memória (evita cold start)

```bash
curl http://localhost:11434/api/generate -X POST \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.2:7b","prompt":"warmup","keep_alive":-1}'
```

### Reduzir tokens se necessário

Em `intent.php`:
```php
'options' => [
    'num_predict' => 200  // padrão: 400
]
```

---

## Troubleshooting

### Botão não aparece na interface

```bash
# 1. Verificar se o plugin está ativo
mysql -u glpi_user -p glpidb \
  -e "SELECT directory, state FROM glpi_plugins WHERE directory='sieassistant';"
# state = 1 significa ativo

# 2. Limpar cache do navegador (Ctrl+Shift+R)

# 3. Verificar console do navegador (F12)
# ui.css e ui.js devem carregar sem erro 404
```

### IA não responde

```bash
# 1. Testar Ollama diretamente
curl http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.2:7b","prompt":"teste","stream":false}'

# 2. Verificar logs do GLPI
tail -f /var/www/html/glpi/files/_log/php-errors.log

# 3. Ativar modo debug
# Adicione ?debug=1 ao endpoint: /ajax/intent.php?debug=1
```

### IA sugere formulário errado

Melhore as descrições e adicione exemplos no prompt em `intent.php`:

```php
$prompt = <<<PROMPT
...
EXEMPLOS:
- "preciso acessar o SAP" → form_id 37
- "impressora não imprime" → form_id 42
- "wifi não conecta" → form_id 63
- "esqueci minha senha" → form_id 72
PROMPT;
```

### Timeout na resposta da IA

```bash
# Aumentar timeout
php bin/console glpi:config:set plugin:sieassistant timeout 30000

# Ou usar modelo menor
php bin/console glpi:config:set plugin:sieassistant ollama_model llama3.2:3b
```

### JSON inválido retornado pelo modelo

O plugin já tem 3 estratégias de extração de JSON. Se ainda falhar, reforce no prompt:

```php
$prompt = <<<PROMPT
CRÍTICO: Retorne APENAS JSON válido.
NÃO adicione texto antes ou depois.
NÃO use markdown (```json).
FORMATO EXATO:
{"form_id":37,"confidence":0.9,"prefill":{},"suggestions":[]}
PROMPT;
```

---

## ROI

Para uma empresa com **200 usuários**:

| Métrica | Valor |
|---------|-------|
| Tempo médio por solicitação (antes) | 5 min |
| Tempo médio por solicitação (depois) | 1 min |
| Solicitações/mês | 200 |
| Horas economizadas/mês | 13,3 h |
| Custo/hora do técnico | R$ 30 |
| **Economia mensal** | **R$ 400** |
| **Custo do plugin** | **R$ 0** |
| **Payback** | **Imediato** |

---

## Roadmap

### v1.2
- [ ] Interface admin para editar formulários sem tocar em código
- [ ] Métricas de taxa de acerto por categoria
- [ ] Cache de respostas comuns (Redis/APCu)

### v1.3
- [ ] Pré-preenchimento server-side via GLPI HL API
- [ ] RAG com base de conhecimento interna (embeddings)
- [ ] Fine-tuning com tickets históricos

### v2.0
- [ ] Sugestão de soluções antes de abrir ticket
- [ ] Integração com bot WhatsApp (este projeto)
- [ ] Analytics preditivo de demandas

---

## Relação com o Bot WhatsApp

Este plugin e o [bot WhatsApp-GLPI](../README.md) são **complementares**:

| Canal | Componente | Usuário |
|-------|------------|---------|
| Interface GLPI | SIE Assistant Plugin | Acessa o GLPI diretamente |
| WhatsApp | N8N + Evolution API | Usa WhatsApp no celular |
| IA | Ollama (compartilhado) | Ambos os canais |

O mesmo servidor Ollama e o mesmo modelo (`glpi-assistant:latest`) podem ser compartilhados entre os dois canais.

---

**Versão:** 1.1.0 | **Licença:** MIT | **Compatível com:** GLPI 11.0+
