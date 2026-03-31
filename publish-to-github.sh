#!/bin/bash
# ============================================================
# Script de publicação no GitHub
# Execute no seu servidor ou máquina local
# ============================================================

# 1. Crie o repositório em https://github.com/new
#    Nome sugerido: glpi-helpdesk-automation
#    Visibilidade: Public
#    NÃO inicialize com README (você já tem um)

# 2. Ajuste estas variáveis:
GITHUB_USER="seu-usuario-github"
REPO_NAME="glpi-helpdesk-automation"

# 3. Execute este script na pasta raiz do projeto

# ── Init e primeiro commit ──────────────────────────────────
git init
git add .
git status  # confira o que está sendo commitado

git commit -m "feat: initial commit — WhatsApp-GLPI automation + SIE Assistant plugin"

# ── Conectar ao GitHub e publicar ──────────────────────────
git remote add origin https://github.com/${GITHUB_USER}/${REPO_NAME}.git
git branch -M main
git push -u origin main

echo ""
echo "✅ Publicado em: https://github.com/${GITHUB_USER}/${REPO_NAME}"
