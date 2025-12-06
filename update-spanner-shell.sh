#!/bin/bash

set -e

REPO_URL="https://github.com/Waelson/spanner-shell.git"
INSTALL_DIR=""
TMP_DIR="/tmp/spanner-shell-update"

echo "==============================================="
echo "🔄 Atualizando Spanner Shell via Git"
echo "==============================================="
echo

# -----------------------------------------------
# Detecta diretório de instalação
# -----------------------------------------------
if [ -f "/opt/homebrew/bin/spanner-shell" ]; then
  INSTALL_DIR="/opt/homebrew/bin"
elif [ -f "/usr/local/bin/spanner-shell" ]; then
  INSTALL_DIR="/usr/local/bin"
else
  echo "❌ spanner-shell não encontrado no sistema."
  echo "➡️  Instale antes de rodar o update."
  exit 1
fi

TARGET_PATH="${INSTALL_DIR}/spanner-shell"

echo "📍 Instalado em: $TARGET_PATH"
echo

# -----------------------------------------------
# Verifica se git existe
# -----------------------------------------------
if ! command -v git >/dev/null 2>&1; then
  echo "❌ Git não está instalado."
  echo "➡️  Instale com: brew install git"
  exit 1
fi

# -----------------------------------------------
# Clona versão mais recente
# -----------------------------------------------
echo "⬇️  Baixando última versão do Git..."

rm -rf "$TMP_DIR"
git clone --quiet "$REPO_URL" "$TMP_DIR"

if [ ! -f "$TMP_DIR/spanner-shell.sh" ]; then
  echo "❌ ERRO: spanner-shell.sh não encontrado no repositório."
  exit 1
fi

# -----------------------------------------------
# Substitui binário
# -----------------------------------------------
echo "♻️  Atualizando binário..."

sudo cp "$TMP_DIR/spanner-shell.sh" "$TARGET_PATH"
sudo chmod +x "$TARGET_PATH"

# -----------------------------------------------
# Limpa arquivos temporários
# -----------------------------------------------
rm -rf "$TMP_DIR"

echo
echo "✅ Spanner Shell atualizado com sucesso!"
echo "➡️  Versão ativa:"
spanner-shell --version || true
echo
echo "==============================================="
