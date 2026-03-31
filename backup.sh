#!/bin/bash
# ============================================================
# Script de Backup - WhatsApp GLPI Bot
# ============================================================
# Uso: bash scripts/backup.sh
# Recomendação: Agendar via cron (ex: diário às 2h)
# ============================================================

set -e

BACKUP_DIR="./backups"
DATE=$(date +%Y-%m-%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/backup-bot-${DATE}.tar.gz"

echo "🔵 Iniciando backup: ${DATE}"

# Criar diretório de backups se não existir
mkdir -p "${BACKUP_DIR}"

# Exportar workflows do N8N (se a API estiver acessível)
if curl -s --max-time 5 http://localhost:5678/healthz > /dev/null 2>&1; then
  echo "📦 Exportando workflows do N8N..."
  # Faça o export manual: N8N > Menu > Export all Workflows as JSON
  # e salve em ./backups/n8n-workflows-${DATE}.json
  echo "   ⚠️  Lembre-se de exportar os workflows manualmente via interface N8N"
fi

# Criar backup dos arquivos essenciais
echo "📦 Comprimindo arquivos..."
tar -czvf "${BACKUP_FILE}" \
  --exclude='./.env' \
  --exclude='./node_modules' \
  --exclude='./postgres_data' \
  .env.example \
  docker-compose.yml \
  evolution_store/ \
  2>/dev/null || true

# Verificar se o .env existe e criar backup separado (mais seguro)
if [ -f ".env" ]; then
  ENV_BACKUP="${BACKUP_DIR}/env-${DATE}.env.encrypted"
  echo "🔐 Criando backup criptografado do .env..."
  echo "   ⚠️  Use: openssl enc -aes-256-cbc -in .env -out ${ENV_BACKUP}"
  echo "   ⚠️  Nunca inclua o .env em backups não criptografados!"
fi

echo ""
echo "✅ Backup concluído: ${BACKUP_FILE}"
echo ""
echo "📋 Arquivos incluídos:"
tar -tzvf "${BACKUP_FILE}" 2>/dev/null | head -20
echo ""
echo "📁 Backups disponíveis:"
ls -lh "${BACKUP_DIR}/"

# Manter apenas os 7 backups mais recentes
echo ""
echo "🧹 Removendo backups antigos (mantendo últimos 7)..."
ls -t "${BACKUP_DIR}"/backup-bot-*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null || true

echo "✅ Processo concluído!"
