#!/bin/bash

set -e

echo "==============================================="
echo "🚀 Instalador do Spanner Shell"
echo "==============================================="
echo

# -----------------------------------------------
# Verifica se o script spanner-shell existe
# -----------------------------------------------
if [ ! -f "./spanner-shell.sh" ]; then
  echo "❌ ERRO: Arquivo 'spanner-shell.sh' não encontrado no diretório atual."
  echo "➡️  Rode este instalador no mesmo diretório do script."
  exit 1
fi

# -----------------------------------------------
# Detecta o diretório padrão de binário no mac
# -----------------------------------------------
if [ -d "/opt/homebrew/bin" ]; then
  INSTALL_DIR="/opt/homebrew/bin"
else
  INSTALL_DIR="/usr/local/bin"
fi

TARGET_PATH="${INSTALL_DIR}/spanner-shell"

echo "📦 Diretório de instalação: ${INSTALL_DIR}"
echo

# -----------------------------------------------
# Copia o script
# -----------------------------------------------
echo "✅ Instalando spanner-shell..."

sudo cp ./spanner-shell.sh "${TARGET_PATH}"
sudo chmod +x "${TARGET_PATH}"

echo "✅ Script copiado para:"
echo "   ${TARGET_PATH}"
echo

# -----------------------------------------------
# Detecta shell do usuário
# -----------------------------------------------
SHELL_NAME=$(basename "$SHELL")

if [[ "$SHELL_NAME" == "zsh" ]]; then
  RC_FILE="$HOME/.zshrc"
elif [[ "$SHELL_NAME" == "bash" ]]; then
  RC_FILE="$HOME/.bashrc"
else
  RC_FILE=""
fi

# -----------------------------------------------
# Cria alias opcional
# -----------------------------------------------
if [[ -n "$RC_FILE" ]]; then
  echo "🔧 Shell detectado: $SHELL_NAME"
  echo

  if ! grep -q "alias spanner=" "$RC_FILE" 2>/dev/null; then
    echo "Deseja criar o alias 'spanner' para o comando? (s/n)"
    read -r CONFIRM

    if [[ "$CONFIRM" == "s" || "$CONFIRM" == "S" ]]; then
      echo "alias spanner='spanner-shell'" >> "$RC_FILE"
      echo "✅ Alias 'spanner' criado em ${RC_FILE}"
      echo "🔁 Rode: source ${RC_FILE}"
    else
      echo "ℹ️  Alias não criado."
    fi
  else
    echo "ℹ️  Alias 'spanner' já existe em ${RC_FILE}"
  fi
else
  echo "⚠️  Shell não reconhecido automaticamente."
  echo "➡️  Caso queira criar alias manualmente:"
  echo "   alias spanner='spanner-shell'"
fi

echo
echo "==============================================="
echo "✅ Instalação concluída com sucesso!"
echo
echo "👉 Agora você pode rodar:"
echo
echo "   spanner-shell"
echo
echo "==============================================="
