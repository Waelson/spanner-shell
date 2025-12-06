#!/bin/bash

# =========================================
# CURSOR: BARRA PISCANTE
# =========================================
echo -ne "\033[5 q"

# =========================================
# VARIÁVEIS DE AMBIENTE
# =========================================
PROJECT_ID="local-project"
INSTANCE_ID="local-instance"
DATABASE_ID="local-db"

# =========================================
# CORES ANSI
# =========================================
RED='\033[0;31m'
GREEN_BRIGHT='\033[1;92m'
WHITE='\033[0;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# =========================================
# VERIFICA SE O GCLOUD EXISTE
# =========================================
clear

if ! command -v gcloud >/dev/null 2>&1; then
  echo -e "${RED}"
  echo "┌──────────────────────────────────────────────────────────────┐"
  echo "│ ❌ ERRO: O gcloud não está instalado neste sistema.          │"
  echo "│                                                              │"
  echo "│   COMO INSTALAR O GCLOUD NO macOS:                           │"
  echo "│                                                              │"
  echo "│ ➜ Via Homebrew (RECOMENDADO):                                │"
  echo "│    brew install --cask google-cloud-sdk                      │"
  echo "│                                                              │"
  echo "│ ➜ Depois da instalação, execute:                             │"
  echo "│    gcloud init                                               │"
  echo "│                                                              │"
  echo "│ ➜ E então rode novamente este script.                        │"
  echo "└──────────────────────────────────────────────────────────────┘"
  echo -e "${NC}"
  echo -ne "\033[1 q"
  exit 1
fi

# =========================================
# CONFIGURA GCLOUD PARA SPANNER EMULATOR
# =========================================
echo "✅ Ativando Spanner Emulator no gcloud..."

echo -ne "${WHITE}"
gcloud config set auth/disable_credentials true --quiet
gcloud config set project ${PROJECT_ID} --quiet
gcloud config set api_endpoint_overrides/spanner http://localhost:9020/ --quiet
echo -ne "${NC}"

clear

# =========================================
# BANNER
# =========================================
echo -e "${GREEN_BRIGHT}"
cat << "EOF"
  ____                                    _____ _          _ _
 / ___| _ __   __ _ _ __  _ __   ___ _ __ / ____| |__   ___| | |
 \___ \| '_ \ / _` | '_ \| '_ \ / _ \ '__| (___ | '_ \ / _ \ | |
  ___) | |_) | (_| | | | | | | |  __/ |   \___ \| | | |  __/ | |
 |____/| .__/ \__,_|_| |_|_| |_|\___|_|   ____) | | | |\___|_|_|
       |_|
 :: Client for Spanner - v1.0 ::
EOF
echo -e "${NC}"

# =========================================
# CABEÇALHO
# =========================================
echo "------------------------------------------------------------------------------------"
echo " ➜ Project:  ${PROJECT_ID} / Instance: ${INSTANCE_ID} / Database: ${DATABASE_ID}"
echo " ➜ Digite seus comandos SQL abaixo ou \\help para obter ajuda"
echo "------------------------------------------------------------------------------------"

# =========================================
# LOOP PRINCIPAL
# =========================================
while true; do
  echo -ne "${GREEN}spanner> ${WHITE}"

  if ! read -r SQL; then
    echo -ne "\033[1 q"
    clear
    echo
    echo "✅  Encerrando Spanner Shell..."
    echo
    exit 0
  fi

  echo -ne "${NC}"

  # exit
  if [ "$SQL" == "exit" ]; then
    echo -ne "\033[1 q"
    clear
    echo
    echo "✅  Encerrando Spanner Shell..."
    echo
    exit 0
  fi

  # =========================================
  # ✅ ATALHO: \help ou \h
  # =========================================
  if [[ "$SQL" == "\help" || "$SQL" == "\h" ]]; then
    echo -e "${WHITE}"
    echo "Comandos disponíveis:"
    echo
    echo "  \\dt               → Lista todas as tabelas"
    echo "  \\d <tabela>       → Describe da tabela"
    echo "  \\ddl <tabela>     → DDL da tabela"
    echo "  \\ddl all          → DDL completo do banco"
    echo "  clear             → Limpa a tela"
    echo "  exit              → Encerra o shell"
    echo "  Ctrl + D          → Encerra o shell"
    echo -e "${NC}"
    echo
    continue
  fi

  # =========================================
  # ✅ ATALHO: \dt
  # =========================================
  if [[ "$SQL" == "\dt" ]]; then
    echo -ne "${WHITE}"
    gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT table_name FROM information_schema.tables WHERE table_schema = '' ORDER BY table_name;"
    echo -ne "${NC}"
    echo
    continue
  fi

  # =========================================
  # ✅ ATALHO: \ddl all
  # =========================================
  if [[ "$SQL" == "\ddl all" ]]; then
    echo -ne "${WHITE}"
    gcloud spanner databases ddl describe ${DATABASE_ID} \
      --instance=${INSTANCE_ID}
    echo -ne "${NC}"
    echo
    continue
  fi

  # =========================================
  # ✅ ATALHO: \d <tabela>
  # =========================================
  if [[ "$SQL" =~ ^\\d[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    echo -ne "${WHITE}"
    gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT column_name, spanner_type, is_nullable FROM information_schema.columns WHERE table_name = '${TABLE_NAME}' ORDER BY ordinal_position;"
    echo -ne "${NC}"
    echo
    continue
  fi

  # =========================================
  # ✅ ATALHO: \ddl <tabela>
  # =========================================
  if [[ "$SQL" =~ ^\\ddl[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    echo
    echo -ne "${WHITE}"
    gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT column_name, spanner_type, is_nullable FROM information_schema.columns WHERE table_name = '${TABLE_NAME}' ORDER BY ordinal_position;"
    echo
    gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT column_name FROM information_schema.index_columns WHERE table_name = '${TABLE_NAME}' AND index_type = 'PRIMARY_KEY' ORDER BY ordinal_position;"
    echo -ne "${NC}"
    echo
    continue
  fi

  # clear
  if [ "$SQL" == "clear" ]; then
    clear
    continue
  fi

  # ignora linha vazia
  if [ -z "$SQL" ]; then
    continue
  fi

  # =========================================
  # ✅ EXECUTA SQL NORMAL
  # =========================================
  echo -ne "${WHITE}"
  gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="$SQL"
  echo -ne "${NC}"

  echo
done
