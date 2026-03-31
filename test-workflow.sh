#!/bin/bash
# ============================================================
# Script de Testes - WhatsApp GLPI Bot
# ============================================================
# Uso: bash scripts/test-workflow.sh
# Pré-requisito: Workflow N8N ativo (toggle verde)
# ============================================================

N8N_URL="http://localhost:5678"
WEBHOOK_URL="${N8N_URL}/webhook/whatsapp-glpi"

# Substitua pelo número cadastrado no GLPI (apenas números, com DDI)
TEST_PHONE="5548999999999"

echo "============================================="
echo "  TESTES DO WORKFLOW WHATSAPP-GLPI BOT"
echo "============================================="
echo ""

# ────────────────────────────────────────────────
# Função de teste
# ────────────────────────────────────────────────
run_test() {
  local TEST_NAME="$1"
  local MESSAGE="$2"
  local REMOTE_JID="${3:-${TEST_PHONE}@s.whatsapp.net}"
  local FROM_ME="${4:-false}"

  echo "🧪 Teste: ${TEST_NAME}"
  echo "   Mensagem: '${MESSAGE}'"

  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${WEBHOOK_URL}" \
    -H "Content-Type: application/json" \
    -d "{
      \"key\": {\"remoteJid\": \"${REMOTE_JID}\", \"fromMe\": ${FROM_ME}},
      \"message\": {\"conversation\": \"${MESSAGE}\"},
      \"messageTimestamp\": $(date +%s)
    }")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | head -1)

  if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ HTTP ${HTTP_CODE} — OK"
  else
    echo "   ❌ HTTP ${HTTP_CODE} — FALHOU"
    echo "   Body: ${BODY}"
  fi
  echo ""

  sleep 2
}

# ────────────────────────────────────────────────
# Verificar se N8N está acessível
# ────────────────────────────────────────────────
echo "🔍 Verificando N8N..."
if ! curl -s --max-time 5 "${N8N_URL}/healthz" > /dev/null; then
  echo "❌ N8N não acessível em ${N8N_URL}"
  echo "   Verifique se os containers estão rodando: docker compose ps"
  exit 1
fi
echo "✅ N8N acessível"
echo ""

# ────────────────────────────────────────────────
# Testes
# ────────────────────────────────────────────────
run_test "Menu Principal" "menu"
run_test "Computador Lento" "meu computador está muito lento"
run_test "Esqueci Senha" "esqueci minha senha"
run_test "Sem Internet" "estou sem internet"
run_test "Problema de Email" "não consigo enviar email"
run_test "Impressora" "minha impressora não imprime"

# ── Testes de Segurança (devem ser bloqueados) ──
echo "--- TESTES DE SEGURANÇA (devem bloquear) ---"
echo ""
run_test "Grupo (deve bloquear)" "teste" "${TEST_PHONE}@g.us"
run_test "FromMe (deve bloquear)" "teste" "${TEST_PHONE}@s.whatsapp.net" "true"

echo "============================================="
echo "  TESTES CONCLUÍDOS"
echo "============================================="
echo ""
echo "📊 Verifique os resultados em:"
echo "   ${N8N_URL} > Executions"
echo ""
echo "💬 Verifique as respostas no WhatsApp do número: ${TEST_PHONE}"
