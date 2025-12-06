#!/bin/bash

set -e

echo "==============================================="
echo "🗑️  Remoção do Spanner Shell"
echo "==============================================="
echo

# -----------------------------------------------
# Detecta diretório de instalação
# -----------------------------------------------
if [ -f "/opt/homebrew/bin/spanner-shell" ]; then
  TARGET_PATH="/opt/homebrew/bin/spanner-shell"
elif [ -f "/usr/local/bin/spanner-shell" ]; then
  TARGET_PATH="/usr/local/bin/spanner-shell"
else
  TARGET_PATH=""
fi

# -----------------------------------------------
# Remove binário
# -----------------------------------------------
if [[ -n "$TARGET_PATH" ]]; then
  echo "🧹 Removendo binário:"
  echo "   $TARGET_PATH"
  sudo rm -f "$TARGET_PATH"
  echo "✅ Binário removido."
else
  echo "ℹ️  Binário 'spanner-shell' não encontrado."
fi

echo

# -----------------------------------------------
# Detecta shell para remover alias
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
# Remove alias
# -----------------------------------------------
if [[ -n "$RC_FILE" && -f "$RC_FILE" ]]; then
  if grep -q "alias spanner='spanner-shell'" "$RC_FILE"; then
    echo "🧽 Removendo alias 'spanner' de $RC_FILE"
    sed -i.bak "/alias spanner='spanner-shell'/d" "$RC_FILE"
    echo "✅ Alias removido."
    echo "🔁 Rode: source $RC_FILE"
  else
    echo "ℹ️  Alias 'spanner' não encontrado em $RC_FILE"
  fi
else
  echo "⚠️  Arquivo de configuração do shell não encontrado."
fi

echo
echo "==============================================="
echo "✅ Remoção concluída com sucesso!"
echo "==============================================="
