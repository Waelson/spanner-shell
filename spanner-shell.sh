#!/bin/bash
SCRIPT_VERSION="1.0.1"

# =========================================
# CURSOR: BARRA PISCANTE
# =========================================
echo -ne "\033[5 q"

# =========================================
# CORES ANSI
# =========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
WHITE='\033[0;37m'
GRAY='\033[0;90m'
NC='\033[0m'

if [[ "$1" == "--version" || "$1" == "-v" ]]; then
  echo "Spanner Shell v${SCRIPT_VERSION}"
  exit 0
fi

# =========================================
# DIRETÓRIOS DE PERFIL
# =========================================
PROFILE_DIR="$HOME/.spanner-shell/profiles"
mkdir -p "$PROFILE_DIR"

# =========================================
# COMANDO: --config  (CRIAR PERFIL)
# =========================================
if [[ "$1" == "--config" ]]; then
  clear
  echo "🔧 Criação de perfil do Spanner Shell"
  echo

  read -p "Nome do perfil (ex: dev, stage, prod): " PROFILE_NAME
  read -p "Tipo (emulator | remote): " TYPE
  read -p "Project ID: " PROJECT_ID
  read -p "Instance ID: " INSTANCE_ID
  read -p "Database ID: " DATABASE_ID

  PROFILE_FILE="${PROFILE_DIR}/${PROFILE_NAME}.env"

  cat <<EOF > "$PROFILE_FILE"
TYPE=${TYPE}
PROJECT_ID=${PROJECT_ID}
INSTANCE_ID=${INSTANCE_ID}
DATABASE_ID=${DATABASE_ID}
EOF

  echo
  echo "✅ Perfil criado com sucesso:"
  echo "➡️  $PROFILE_FILE"
  echo
  echo "Use assim:"
  echo "   spanner-shell --profile ${PROFILE_NAME}"
  echo
  exit 0
fi

# =========================================
# COMANDO: --profile <nome>
# =========================================
if [[ "$1" == "--profile" && -n "$2" ]]; then
  PROFILE_FILE="${PROFILE_DIR}/${2}.env"

  if [[ ! -f "$PROFILE_FILE" ]]; then
    echo "❌ Perfil '$2' não encontrado."
    exit 1
  fi

  source "$PROFILE_FILE"
fi

# =========================================
# VALIDA VARIÁVEIS
# =========================================
if [[ -z "$PROJECT_ID" || -z "$INSTANCE_ID" || -z "$DATABASE_ID" || -z "$TYPE" ]]; then
  echo "❌ Nenhum perfil carregado."
  echo "Use:"
  echo "  spanner-shell --config"
  echo "  spanner-shell --profile dev"
  exit 1
fi

# =========================================
# VERIFICA SE O GCLOUD EXISTE
# =========================================
clear

if ! command -v gcloud >/dev/null 2>&1; then
  echo -e "${RED}"
  echo "❌ gcloud não está instalado."
  echo "➡️  brew install --cask google-cloud-sdk"
  echo -e "${NC}"
  echo -ne "\033[1 q"
  exit 1
fi

# =========================================
# CONFIGURA EMULATOR OU REMOTO
# =========================================
echo -e "${WHITE}"
if [[ "$TYPE" == "emulator" ]]; then
  echo "✅ Usando Spanner Emulator"
  gcloud config set auth/disable_credentials true --quiet
  gcloud config set api_endpoint_overrides/spanner http://localhost:9020/ --quiet
else
  echo "✅ Usando Spanner Remoto"
  gcloud config unset api_endpoint_overrides/spanner --quiet
fi

gcloud config set project ${PROJECT_ID} --quiet
echo -e "${NC}"

clear

# =========================================
# BANNER
# =========================================
echo -e "${GREEN}"
echo " -----------------------------------------------------------------"
cat << "EOF"
/  ____                                     _____ _          _ _  \
| / ___| _ __   __ _ _ __  _ __   ___ _ __ / ____| |__   ___| | | |
| \___ \| '_ \ / _` | '_ \| '_ \ / _ \ '__| (___ | '_ \ / _ \ | | |
|  ___) | |_) | (_| | | | | | | |  __/ |   \___ \| | | |  __/ | | |
| |____/| .__/ \__,_|_| |_|_| |_|\___|_|   ____) | | | |\___|_|_| |
\       |_|                                                       /
EOF
echo " -----------------------------------------------------------------"
echo " :: v${SCRIPT_VERSION}::"
echo -e "${NC}"


# =========================================
# LOOP PRINCIPAL
# =========================================
while true; do
  echo -ne "${GREEN}spanner> ${WHITE}"

  if ! read -r SQL; then
    clear
    echo "✅ Encerrando Spanner Shell..."
    exit 0
  fi

  echo -ne "${NC}"

  if [ "$SQL" == "exit" ]; then
    clear
    echo "✅ Encerrando Spanner Shell..."
    exit 0
  fi

  # HELP
  if [[ "$SQL" == "\help" || "$SQL" == "\h" ]]; then
    echo -e "${WHITE}"
    echo "Comandos disponíveis:"
    echo "  \\dt               → Lista tabelas"
    echo "  \\d <tabela>       → Describe tabela"
    echo "  \\ddl <tabela>     → DDL tabela"
    echo "  \\ddl all          → DDL completo"
    echo "  \\cfg              → Exibe as configurações"
    echo "  clear             → Limpar tela"
    echo "  exit              → Sair"
    echo -e "${NC}"
    continue
  fi

  # \cfg
  if [[ "$SQL" == "\cfg" ]]; then
    echo -e "${WHITE}"
    echo "Configurações:"
    echo "  Profile:  ${2}"
    echo "  Type:     ${TYPE}"
    echo "  Project:  ${PROJECT_ID}"
    echo "  Instance: ${INSTANCE_ID}"
    echo "  Database: ${DATABASE_ID}"
    echo -e "${NC}"
    continue
  fi

  # \dt
  if [[ "$SQL" == "\dt" ]]; then
    echo -e "${WHITE}"
    gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT table_name FROM information_schema.tables WHERE table_schema = '' ORDER BY table_name;"
    echo -e "${NC}"
    continue
  fi

  # \ddl all
  if [[ "$SQL" == "\ddl all" ]]; then
    echo -e "${WHITE}"
    gcloud spanner databases ddl describe ${DATABASE_ID} \
      --instance=${INSTANCE_ID}
    echo -e "${NC}"
    continue
  fi

  # \d <tabela>
  if [[ "$SQL" =~ ^\\d[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    echo -e "${WHITE}"
    gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT column_name, spanner_type, is_nullable FROM information_schema.columns WHERE table_name = '${TABLE_NAME}' ORDER BY ordinal_position;"
    echo -e "${NC}"
    continue
  fi

  # clear
  if [ "$SQL" == "clear" ]; then
    clear
    continue
  fi

  # SQL normal
  if [ -n "$SQL" ]; then
    echo -e "${WHITE}"
    gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="$SQL"
    echo -e "${NC}"
  fi
done
