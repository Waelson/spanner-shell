#!/bin/bash
SCRIPT_VERSION="1.0.12"

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
# CONFIGURAÇÃO DE HISTÓRICO ISOLADO
# =========================================
HISTORY_DIR="$HOME/.spanner-shell"
HISTORY_FILE="${HISTORY_DIR}/history"
mkdir -p "$HISTORY_DIR"

# =========================================
# COMANDO: --config  (CRIAR PERFIL)
# =========================================
if [[ "$1" == "--config" ]]; then
  clear
  echo "🔧 Criação de perfil do Spanner Shell"
  echo

  # Validar nome do perfil - não deve conter espaços nem caracteres especiais
  while true; do
    read -p "Nome do perfil (ex: dev, stage, prod): " PROFILE_NAME
    if [[ "$PROFILE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      break
    else
      echo -e "${RED}❌ Nome do perfil inválido. Use apenas letras, números, hífens e underscores (sem espaços).${NC}"
    fi
  done
  
  # Validar TYPE - deve ser emulator ou remote
  while true; do
    read -p "Tipo (emulator | remote): " TYPE
    if [[ "$TYPE" == "emulator" || "$TYPE" == "remote" ]]; then
      break
    else
      echo -e "${RED}❌ Tipo inválido. Deve ser 'emulator' ou 'remote'.${NC}"
    fi
  done
  
  # Validar Project ID - não deve conter espaços
  while true; do
    read -p "Project ID: " PROJECT_ID
    if [[ -n "$PROJECT_ID" && ! "$PROJECT_ID" =~ [[:space:]] ]]; then
      break
    else
      echo -e "${RED}❌ Project ID inválido. Não pode conter espaços.${NC}"
    fi
  done
  
  # Validar Instance ID - não deve conter espaços
  while true; do
    read -p "Instance ID: " INSTANCE_ID
    if [[ -n "$INSTANCE_ID" && ! "$INSTANCE_ID" =~ [[:space:]] ]]; then
      break
    else
      echo -e "${RED}❌ Instance ID inválido. Não pode conter espaços.${NC}"
    fi
  done
  
  # Validar Database ID - não deve conter espaços
  while true; do
    read -p "Database ID: " DATABASE_ID
    if [[ -n "$DATABASE_ID" && ! "$DATABASE_ID" =~ [[:space:]] ]]; then
      break
    else
      echo -e "${RED}❌ Database ID inválido. Não pode conter espaços.${NC}"
    fi
  done

  # Se for emulator, perguntar pelo endpoint opcional
  ENDPOINT=""
  if [[ "$TYPE" == "emulator" ]]; then
    read -p "Endpoint (opcional, padrão: http://localhost:9020/): " ENDPOINT_INPUT
    if [[ -n "$ENDPOINT_INPUT" ]]; then
      # Garante que o endpoint sempre termine com "/"
      if [[ "$ENDPOINT_INPUT" != */ ]]; then
        ENDPOINT="${ENDPOINT_INPUT}/"
      else
        ENDPOINT="$ENDPOINT_INPUT"
      fi
    fi
  fi

  PROFILE_FILE="${PROFILE_DIR}/${PROFILE_NAME}.env"

  # Monta o conteúdo do arquivo .env
  cat <<EOF > "$PROFILE_FILE"
TYPE=${TYPE}
PROJECT_ID=${PROJECT_ID}
INSTANCE_ID=${INSTANCE_ID}
DATABASE_ID=${DATABASE_ID}
EOF

  # Adiciona ENDPOINT apenas se foi informado
  if [[ -n "$ENDPOINT" ]]; then
    echo "ENDPOINT=${ENDPOINT}" >> "$PROFILE_FILE"
  fi

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
# COMANDO: --list-profile (LISTAR E SELECIONAR PERFIL)
# =========================================
if [[ "$1" == "--list-profile" ]]; then
  clear
  echo "📋 Listando perfis disponíveis..."
  echo

  # Buscar todos os perfis
  PROFILES=()
  PROFILE_NAMES=()

  # Buscar todos os arquivos .env no diretório de perfis
  for profile_file in "$PROFILE_DIR"/*.env; do
    if [[ -f "$profile_file" ]]; then
      # Extrair nome do perfil (sem extensão .env)
      profile_name=$(basename "$profile_file" .env)
      PROFILES+=("$profile_file")
      PROFILE_NAMES+=("$profile_name")
    fi
  done

  # Verificar se há perfis
  if [[ ${#PROFILES[@]} -eq 0 ]]; then
    echo -e "${RED}❌ Nenhum perfil encontrado.${NC}"
    echo -e "${WHITE}➡️  Crie um perfil com: spanner-shell --config${NC}"
    echo
    exit 1
  fi

  # Exibir lista numerada de perfis
  echo -e "${WHITE}📋 Perfis disponíveis:${NC}"
  echo

  # Exibir perfis com informações
  for i in "${!PROFILE_NAMES[@]}"; do
    idx=$((i + 1))
    profile_name="${PROFILE_NAMES[$i]}"
    profile_file="${PROFILES[$i]}"

    # Ler informações do arquivo sem usar source (para não poluir variáveis)
    # Extrair TYPE e PROJECT_ID diretamente do arquivo
    profile_type=$(grep "^TYPE=" "$profile_file" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "unknown")
    profile_project=$(grep "^PROJECT_ID=" "$profile_file" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "unknown")
    
    echo -e "${WHITE}   ${idx}) ${GREEN}${profile_name}${NC} (${profile_type}) - ${profile_project}"
  done

  echo
  echo -ne "${WHITE}Qual perfil deseja usar? (digite o número): ${NC}"
  read -r SELECTED_NUM

  # Validar entrada
  if [[ -z "$SELECTED_NUM" ]]; then
    echo -e "${RED}❌ Nenhum número foi informado.${NC}"
    exit 1
  fi

  # Validar se é um número
  if ! [[ "$SELECTED_NUM" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}❌ Entrada inválida. Por favor, digite um número.${NC}"
    exit 1
  fi

  # Validar range
  if [[ "$SELECTED_NUM" -lt 1 || "$SELECTED_NUM" -gt ${#PROFILES[@]} ]]; then
    echo -e "${RED}❌ Número inválido. Por favor, escolha um número entre 1 e ${#PROFILES[@]}.${NC}"
    exit 1
  fi

  # Obter índice (subtrair 1 porque array começa em 0)
  idx=$((SELECTED_NUM - 1))
  SELECTED_PROFILE="${PROFILES[$idx]}"
  SELECTED_NAME="${PROFILE_NAMES[$idx]}"

  # Carregar perfil selecionado
  source "$SELECTED_PROFILE"

  echo
  echo -e "${GREEN}✅ Perfil '${SELECTED_NAME}' carregado com sucesso!${NC}"
  echo
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

  SELECTED_NAME="$2"
  source "$PROFILE_FILE"
fi

# =========================================
# VALIDA VARIÁVEIS
# =========================================
if [[ -z "$PROJECT_ID" || -z "$INSTANCE_ID" || -z "$DATABASE_ID" || -z "$TYPE" ]]; then
  echo "❌ Nenhum perfil carregado."
  echo "Use:"
  echo "  spanner-shell --config        # Criar um novo perfil"
  echo "  spanner-shell --list-profile   # Listar e selecionar um perfil"
  echo "  spanner-shell --profile dev    # Usar um perfil específico"
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
  
  # Usa endpoint do perfil se disponível, senão usa o padrão
  if [[ -n "$ENDPOINT" ]]; then
    gcloud config set api_endpoint_overrides/spanner ${ENDPOINT} --quiet
  else
    gcloud config set api_endpoint_overrides/spanner http://localhost:9020/ --quiet
  fi
else
  echo "✅ Usando Spanner Remoto"
  gcloud config set auth/disable_credentials false
  gcloud config unset api_endpoint_overrides/spanner --quiet
  #gcloud auth application-default login
  ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

  if [[ -z "$ACTIVE_ACCOUNT" ]]; then
    echo -e "${RED}❌ Nenhuma autenticação ativa encontrada no gcloud.${NC}"
    echo -e "${WHITE}➡️  Executando: gcloud auth login${NC}"
    echo

    gcloud auth login

    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

    if [[ -z "$ACTIVE_ACCOUNT" ]]; then
      echo -e "${RED}❌ Falha ao autenticar no gcloud.${NC}"
      exit 1
    fi
  fi

  echo -e "${GREEN}✅ Autenticado no gcloud como: ${ACTIVE_ACCOUNT}${NC}"


fi

gcloud config set project ${PROJECT_ID} --quiet
echo -e "${NC}"

clear

# =========================================
# FUNÇÃO: Exibir banner
# =========================================
show_banner() {
  echo -e "${GREEN}"
  cat << "EOF"
  ____                                     _____ _          _ _  
 / ___| _ __   __ _ _ __  _ __   ___ _ __ / ____| |__   ___| | | 
 \___ \| '_ \ / _` | '_ \| '_ \ / _ \ '__| (___ | '_ \ / _ \ | | 
  ___) | |_) | (_| | | | | | | |  __/ |   \___ \| | | |  __/ | | 
 |____/| .__/ \__,_|_| |_|_| |_|\___|_|   ____) | | | |\___|_|_| 
       |_|                                                       
EOF
  echo 
  echo -e "${GRAY}_________________${NC}"
  echo
  echo -e "${GRAY} \033[1mVersão\033[0;90m: v${SCRIPT_VERSION}${NC}"
  if [[ -n "$SELECTED_NAME" ]]; then
    echo -e "${GRAY} \033[1mPerfil\033[0;90m: ${SELECTED_NAME}${NC}"
  fi
  echo -e "${GRAY}_________________${NC}"
  echo -e "${NC}"
}

# =========================================
# BANNER
# =========================================
show_banner


# =========================================
# FUNÇÃO: Limpar códigos de escape ANSI
# =========================================
clean_ansi() {
  local text="$1"
  # Remove todos os tipos de códigos de escape ANSI de forma mais agressiva
  # Remove sequências ESC[ seguido de números/pontos/vírgulas terminando em 'm'
  text=$(printf '%s' "$text" | sed 's/\x1b\[[0-9;]*m//g')
  # Remove sequências literais \033[ (escaped)
  text=$(printf '%s' "$text" | sed 's/\\033\[[0-9;]*m//g')
  # Remove sequências ESC[ sem 'm' (truncadas)
  text=$(printf '%s' "$text" | sed 's/\x1b\[[0-9;]*//g')
  # Remove sequências \033[ (não escaped)
  text=$(printf '%s' "$text" | sed 's/\033\[[0-9;]*m//g')
  # Remove qualquer caractere de controle restante (exceto \n, \t, etc)
  text=$(printf '%s' "$text" | tr -d '\000-\010\013-\037\177')
  printf '%s' "$text"
}

# =========================================
# FUNÇÃO: Tratar mensagem de erro (substitui erros de sintaxe por "Comando desconhecido")
# =========================================
format_error_message() {
  local error_msg="$1"
  
  # Converte para minúsculas para comparação case-insensitive
  local error_lower=$(echo "$error_msg" | tr '[:upper:]' '[:lower:]')
  
  # Verifica se é erro de sintaxe
  if [[ "$error_lower" =~ "syntax error" ]]; then
    echo "Comando desconhecido"
  else
    echo "$error_msg"
  fi
}

# =========================================
# FUNÇÃO: Gerar valor de exemplo baseado no tipo
# =========================================
generate_example_value() {
  local col_type="$1"
  local is_nullable="$2"
  
  # Se for nullable e aleatório, pode ser NULL
  if [[ "$is_nullable" == "YES" && $((RANDOM % 3)) -eq 0 ]]; then
    echo "NULL"
    return
  fi
  
  # Remove tamanho do tipo (ex: STRING(128) -> STRING)
  local base_type=$(echo "$col_type" | sed 's/([0-9]*)//g' | tr '[:lower:]' '[:upper:]')
  
  case "$base_type" in
    "INT64")
      echo "123"
      ;;
    "FLOAT64")
      echo "123.45"
      ;;
    "BOOL")
      echo "TRUE"
      ;;
    "STRING"|"BYTES")
      echo "'exemplo'"
      ;;
    "DATE")
      echo "DATE '2024-01-15'"
      ;;
    "TIMESTAMP")
      echo "CURRENT_TIMESTAMP()"
      ;;
    "ARRAY<STRING>"|"ARRAY<INT64>"|"ARRAY<FLOAT64>")
      local inner_type=$(echo "$col_type" | sed 's/ARRAY<\(.*\)>/\1/' | sed 's/([0-9]*)//g' | tr '[:lower:]' '[:upper:]')
      case "$inner_type" in
        "STRING")
          echo "ARRAY['valor1', 'valor2']"
          ;;
        "INT64")
          echo "ARRAY[1, 2, 3]"
          ;;
        "FLOAT64")
          echo "ARRAY[1.1, 2.2, 3.3]"
          ;;
        *)
          echo "ARRAY[]"
          ;;
      esac
      ;;
    *)
      echo "'valor'"
      ;;
  esac
}

# =========================================
# FUNÇÃO: Gerar DML de exemplo para uma tabela
# =========================================
generate_dml_examples() {
  local table_name="$1"
  
  echo -e "${WHITE}"
  echo "📝 DML de exemplo para tabela: ${table_name}"
  echo "=========================================="
  echo
  
  # Obtém informações das colunas (formato tabular)
  local columns_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="SELECT column_name, spanner_type, is_nullable FROM information_schema.columns WHERE table_name = '${table_name}' ORDER BY ordinal_position;" 2>/dev/null)
  
  if [[ -z "$columns_output" || "$columns_output" =~ "not found" ]]; then
    echo -e "${RED}❌ Tabela '${table_name}' não encontrada.${NC}"
    echo -e "${NC}"
    return 1
  fi
  
  # Obtém chaves primárias
  local pk_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="SELECT column_name FROM information_schema.index_columns WHERE table_name = '${table_name}' AND index_name = 'PRIMARY_KEY' ORDER BY ordinal_position;" 2>/dev/null)
  
  # Extrai nomes das colunas e tipos
  local column_names=()
  local column_types=()
  local nullable_flags=()
  local pk_columns=()
  
  # Parse colunas (pula cabeçalho)
  local first_line=true
  while IFS= read -r line; do
    if [[ "$first_line" == true ]]; then
      first_line=false
      continue
    fi
    if [[ -n "$line" ]]; then
      # Parse linha tabular: column_name \t spanner_type \t is_nullable
      local col_name=$(echo "$line" | awk '{print $1}')
      local col_type=$(echo "$line" | awk '{for(i=2;i<NF;i++) printf "%s ", $i; print $(NF-1)}' | sed 's/[[:space:]]*$//')
      local is_null=$(echo "$line" | awk '{print $NF}')
      
      if [[ -n "$col_name" && "$col_name" != "column_name" ]]; then
        column_names+=("$col_name")
        column_types+=("$col_type")
        nullable_flags+=("$is_null")
      fi
    fi
  done <<< "$columns_output"
  
  # Parse chaves primárias (pula cabeçalho)
  first_line=true
  while IFS= read -r line; do
    if [[ "$first_line" == true ]]; then
      first_line=false
      continue
    fi
    if [[ -n "$line" ]]; then
      local pk_col=$(echo "$line" | awk '{print $1}')
      if [[ -n "$pk_col" && "$pk_col" != "column_name" ]]; then
        pk_columns+=("$pk_col")
      fi
    fi
  done <<< "$pk_output"
  
  if [[ ${#column_names[@]} -eq 0 ]]; then
    echo -e "${RED}❌ Não foi possível obter informações da tabela.${NC}"
    echo -e "${NC}"
    return 1
  fi
  
  # Função auxiliar para encontrar tipo de coluna
  get_column_type() {
    local col_name="$1"
    for i in "${!column_names[@]}"; do
      if [[ "${column_names[$i]}" == "$col_name" ]]; then
        echo "${column_types[$i]}"
        return
      fi
    done
  }
  
  # Gera INSERT
  echo -e "${WHITE}-- INSERT${NC}"
  echo -e "${WHITE}INSERT INTO ${table_name} ("
  local cols_list=""
  local vals_list=""
  for i in "${!column_names[@]}"; do
    if [[ $i -gt 0 ]]; then
      cols_list+=", "
      vals_list+=", "
    fi
    cols_list+="${column_names[$i]}"
    vals_list+=$(generate_example_value "${column_types[$i]}" "${nullable_flags[$i]}")
  done
  echo -e "${WHITE}  ${cols_list}"
  echo -e "${WHITE}) VALUES ("
  echo -e "${WHITE}  ${vals_list}"
  echo -e "${WHITE});"
  echo
  
  # Gera SELECT
  echo -e "${WHITE}-- SELECT${NC}"
  echo -e "${WHITE}SELECT * FROM ${table_name}"
  if [[ ${#pk_columns[@]} -gt 0 ]]; then
    echo "WHERE "
    local where_clause=""
    for i in "${!pk_columns[@]}"; do
      [[ $i -gt 0 ]] && where_clause+=" AND "
      local pk_type=$(get_column_type "${pk_columns[$i]}")
      where_clause+="${pk_columns[$i]} = $(generate_example_value "$pk_type" "NO")"
    done
    echo -e "${WHITE}  ${where_clause};"
  else
    echo -e "${WHITE}LIMIT 10;"
  fi
  echo
  
  # Gera UPDATE
  echo -e "${WHITE}-- UPDATE${NC}"
  echo -e "${WHITE}UPDATE ${table_name}"
  echo -e "${WHITE}SET "
  local set_clause=""
  local first=true
  for i in "${!column_names[@]}"; do
    # Não atualiza chaves primárias
    local is_pk=false
    for pk_col in "${pk_columns[@]}"; do
      if [[ "${column_names[$i]}" == "$pk_col" ]]; then
        is_pk=true
        break
      fi
    done
    if [[ "$is_pk" == false ]]; then
      if [[ "$first" == false ]]; then
        set_clause+=", "
      fi
      set_clause+="${column_names[$i]} = $(generate_example_value "${column_types[$i]}" "${nullable_flags[$i]}")"
      first=false
    fi
  done
  echo -e "${WHITE}  ${set_clause}"
  if [[ ${#pk_columns[@]} -gt 0 ]]; then
    echo -e "${WHITE}WHERE "
    local where_clause=""
    for i in "${!pk_columns[@]}"; do
      [[ $i -gt 0 ]] && where_clause+=" AND "
      local pk_type=$(get_column_type "${pk_columns[$i]}")
      where_clause+="${pk_columns[$i]} = $(generate_example_value "$pk_type" "NO")"
    done
    echo -e "${WHITE}  ${where_clause};"
  else
    echo -e "${WHITE}WHERE <condição>;"
  fi
  echo
  
  # Gera DELETE
  echo -e "${WHITE}-- DELETE${NC}"
  echo -e "${WHITE}DELETE FROM ${table_name}"
  if [[ ${#pk_columns[@]} -gt 0 ]]; then
    echo -e "${WHITE}WHERE "
    local where_clause=""
    for i in "${!pk_columns[@]}"; do
      [[ $i -gt 0 ]] && where_clause+=" AND "
      local pk_type=$(get_column_type "${pk_columns[$i]}")
      where_clause+="${pk_columns[$i]} = $(generate_example_value "$pk_type" "NO")"
    done
    echo -e "${WHITE}  ${where_clause};"
  else
    echo -e "${WHITE}WHERE <condição>;"
  fi
  echo
  
  echo -e "${NC}"
}

# =========================================
# FUNÇÃO: Obter chave primária de uma tabela
# =========================================
get_table_primary_key() {
  local table_name="$1"
  
  local pk_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="SELECT column_name FROM information_schema.index_columns WHERE table_name = '${table_name}' AND index_name = 'PRIMARY_KEY' ORDER BY ordinal_position LIMIT 1;" 2>/dev/null)
  
  # Parse resultado (pula cabeçalho)
  local first_line=true
  while IFS= read -r line; do
    if [[ "$first_line" == true ]]; then
      first_line=false
      continue
    fi
    if [[ -n "$line" && "$line" != "column_name" ]]; then
      local pk_col=$(echo "$line" | awk '{print $1}')
      if [[ -n "$pk_col" ]]; then
        echo "$pk_col"
        return 0
      fi
    fi
  done <<< "$pk_output"
  
  return 1
}

# =========================================
# FUNÇÃO: Obter primeira coluna de uma tabela
# =========================================
get_table_first_column() {
  local table_name="$1"
  
  local columns_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="SELECT column_name FROM information_schema.columns WHERE table_name = '${table_name}' ORDER BY ordinal_position LIMIT 1;" 2>/dev/null)
  
  # Parse resultado (pula cabeçalho)
  local first_line=true
  while IFS= read -r line; do
    if [[ "$first_line" == true ]]; then
      first_line=false
      continue
    fi
    if [[ -n "$line" && "$line" != "column_name" ]]; then
      local col_name=$(echo "$line" | awk '{print $1}')
      if [[ -n "$col_name" ]]; then
        echo "$col_name"
        return 0
      fi
    fi
  done <<< "$columns_output"
  
  return 1
}

# =========================================
# FUNÇÃO: Validar se coluna existe na tabela
# =========================================
validate_column_exists() {
  local table_name="$1"
  local column_name="$2"
  
  local result=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="SELECT COUNT(*) as cnt FROM information_schema.columns WHERE table_name = '${table_name}' AND column_name = '${column_name}';" 2>/dev/null)
  
  # Parse resultado (procura por "1" ou número > 0)
  if [[ "$result" =~ [1-9] ]]; then
    return 0
  fi
  
  return 1
}

# =========================================
# FUNÇÃO: Obter coluna padrão para ordenação
# =========================================
get_default_order_column() {
  local table_name="$1"
  
  # Tenta obter chave primária primeiro
  local pk_col=$(get_table_primary_key "$table_name")
  if [[ -n "$pk_col" ]]; then
    echo "$pk_col"
    return 0
  fi
  
  # Se não houver chave primária, usa primeira coluna
  local first_col=$(get_table_first_column "$table_name")
  if [[ -n "$first_col" ]]; then
    echo "$first_col"
    return 0
  fi
  
  return 1
}

# =========================================
# FUNÇÃO: Obter tipo de uma coluna
# =========================================
get_column_type() {
  local table_name="$1"
  local column_name="$2"
  
  local result=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="SELECT spanner_type FROM information_schema.columns WHERE table_name = '${table_name}' AND column_name = '${column_name}';" 2>/dev/null)
  
  # Parse resultado (pula cabeçalho)
  local first_line=true
  while IFS= read -r line; do
    if [[ "$first_line" == true ]]; then
      first_line=false
      continue
    fi
    if [[ -n "$line" && "$line" != "spanner_type" ]]; then
      # Remove tamanho do tipo (ex: STRING(128) -> STRING)
      local base_type=$(echo "$line" | sed 's/([0-9]*)//g' | tr '[:lower:]' '[:upper:]')
      echo "$base_type"
      return 0
    fi
  done <<< "$result"
  
  return 1
}

# =========================================
# FUNÇÃO: Salvar comando no histórico
# =========================================
save_to_history() {
  local cmd="$1"
  # Ignora comandos vazios ou apenas espaços
  if [[ -z "${cmd// }" ]]; then
    return
  fi
  
  # Remove códigos de escape ANSI antes de salvar
  local clean_cmd=$(clean_ansi "$cmd")
  
  # Ignora comandos que são comentários ou linhas de código
  if [[ "$clean_cmd" =~ ^[[:space:]]*# ]]; then
    return
  fi
  
  # Ignora comandos que são apenas espaços ou caracteres especiais
  if [[ ! "$clean_cmd" =~ [a-zA-Z0-9] ]]; then
    return
  fi
  
  # Ignora comandos muito longos (máximo 500 caracteres)
  if [[ ${#clean_cmd} -gt 500 ]]; then
    return
  fi
  
  # Ignora comandos que parecem ser código do script (contêm padrões bash)
  if [[ "$clean_cmd" =~ (BASH_REMATCH|HISTFILE|HISTSIZE|HISTFILESIZE|clean_ansi|format_table|IFS=|read -r -e|printf|sed -E|gcloud spanner|export |local |if \[\[|elif \[\[|else|fi|while|for|do|done|function |return |echo -e) ]]; then
    return
  fi
  
  # Adiciona ao histórico do bash (que está isolado)
  history -s "$clean_cmd"
  
  # Salva no arquivo imediatamente
  history -w "$HISTORY_FILE"
}

# =========================================
# FUNÇÃO: Exportar resultados para CSV
# =========================================
export_to_csv() {
  local output_data="$1"
  local output_file="$2"
  
  # Cria diretório se não existir
  local output_dir=$(dirname "$output_file")
  if [[ -n "$output_dir" && "$output_dir" != "." ]]; then
    if ! mkdir -p "$output_dir" 2>/dev/null; then
      echo "Erro ao criar diretório: $output_dir" >&2
      return 1
    fi
  fi
  
  # Processa dados tabulares
  local first_line=true
  local line_count=0
  
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      continue
    fi
    
    if [[ "$first_line" == true ]]; then
      # Primeira linha = cabeçalho - converte tabs para vírgulas
      first_line=false
      local csv_header=$(echo "$line" | tr '\t' ',')
      if ! echo "$csv_header" > "$output_file" 2>/dev/null; then
        echo "Erro ao escrever cabeçalho no arquivo: $output_file" >&2
        return 2
      fi
      line_count=1
    else
      # Linhas de dados - processa cada campo
      local csv_line=""
      IFS=$'\t' read -ra FIELDS <<< "$line"
      local first_field=true
      
      for field in "${FIELDS[@]}"; do
        if [[ "$first_field" == false ]]; then
          csv_line+=","
        fi
        first_field=false
        
        # Se campo contém vírgula, aspas ou quebra de linha, envolve em aspas
        if [[ "$field" =~ [,,\"$'\n'$'\r'] ]]; then
          # Escapa aspas duplas (duplica-as)
          field=$(echo "$field" | sed 's/"/""/g')
          csv_line+="\"$field\""
        else
          csv_line+="$field"
        fi
      done
      
      if ! echo "$csv_line" >> "$output_file" 2>/dev/null; then
        echo "Erro ao escrever linha no arquivo: $output_file" >&2
        return 3
      fi
      line_count=$((line_count + 1))
    fi
  done <<< "$output_data"
  
  # Retorna line_count via stdout apenas se tudo foi bem-sucedido
  echo "$line_count"
  return 0
}

# =========================================
# FUNÇÃO: Exportar resultados para JSON
# =========================================
export_to_json() {
  local json_data="$1"
  local output_file="$2"
  
  # Cria diretório se não existir
  local output_dir=$(dirname "$output_file")
  if [[ -n "$output_dir" && "$output_dir" != "." ]]; then
    mkdir -p "$output_dir" 2>/dev/null
  fi
  
  # Verifica se jq está disponível
  if command -v jq >/dev/null 2>&1; then
    # Usa jq para formatar JSON de forma bonita
    echo "$json_data" | jq '.' > "$output_file" 2>/dev/null
    if [[ $? -eq 0 ]]; then
      # Conta linhas (número de objetos no array)
      local line_count=$(echo "$json_data" | jq 'if type == "array" then length elif type == "object" and has("rows") then (.rows | length) else 0 end' 2>/dev/null || echo "0")
      echo "$line_count"
      return 0
    fi
  fi
  
  # Fallback: salva JSON sem formatação (já deve estar válido do gcloud)
  echo "$json_data" > "$output_file"
  if [[ $? -eq 0 ]]; then
    # Tenta contar objetos manualmente (aproximado)
    local line_count=$(echo "$json_data" | grep -o '^{' | wc -l | tr -d ' ')
    if [[ -z "$line_count" || "$line_count" == "0" ]]; then
      line_count=1
    fi
    echo "$line_count"
    return 0
  fi
  
  return 1
}

# =========================================
# FUNÇÃO: Detectar tipo de coluna (numérica ou texto)
# =========================================
detect_column_type() {
  local sample_value="$1"
  
  # Remove espaços
  sample_value=$(echo "$sample_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Se vazio ou NULL, assume texto
  if [[ -z "$sample_value" || "$sample_value" == "NULL" ]]; then
    echo "text"
    return
  fi
  
  # Verifica se é número (inteiro ou decimal)
  if [[ "$sample_value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    echo "numeric"
  else
    echo "text"
  fi
}

# =========================================
# FUNÇÃO: Detectar se um comando SQL é um SELECT
# =========================================
is_select_query() {
  local sql="$1"
  
  # Remove espaços iniciais e finais
  sql=$(echo "$sql" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Remove comentários SQL de linha única (-- comentário)
  sql=$(echo "$sql" | sed 's/--.*$//')
  
  # Remove comentários SQL de bloco simples (/* comentário */)
  # Nota: Esta é uma implementação simples que não lida com comentários multi-linha complexos
  sql=$(echo "$sql" | sed 's/\/\*[^*]*\*\///g')
  
  # Remove espaços novamente após remover comentários
  sql=$(echo "$sql" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Verifica se começa com SELECT (case-insensitive)
  if [[ "$sql" =~ ^[Ss][Ee][Ll][Ee][Cc][Tt][[:space:]] ]]; then
    return 0
  fi
  
  return 1
}

# =========================================
# FUNÇÃO: Calcular larguras das colunas
# =========================================
calculate_column_widths() {
  local data="$1"
  local max_width="${2:-50}"  # Largura máxima padrão por coluna
  
  # Array para armazenar larguras
  declare -a widths
  
  # Processa primeira linha (cabeçalho)
  local first_line=true
  local num_columns=0
  
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      continue
    fi
    
    IFS=$'\t' read -ra FIELDS <<< "$line"
    
    if [[ "$first_line" == true ]]; then
      # Primeira linha = cabeçalho
      num_columns=${#FIELDS[@]}
      for i in "${!FIELDS[@]}"; do
        widths[$i]=${#FIELDS[$i]}
      done
      first_line=false
    else
      # Linhas de dados - atualiza largura se necessário
      for i in "${!FIELDS[@]}"; do
        if [[ $i -lt $num_columns ]]; then
          local field_len=${#FIELDS[$i]}
          if [[ $field_len -gt ${widths[$i]} ]]; then
            widths[$i]=$field_len
          fi
        fi
      done
    fi
  done <<< "$data"
  
  # Aplica limite máximo e imprime larguras
  for i in $(seq 0 $((num_columns - 1))); do
    if [[ ${widths[$i]} -gt $max_width ]]; then
      widths[$i]=$max_width
    fi
    echo "${widths[$i]}"
  done
}

# =========================================
# FUNÇÃO: Formatar e exibir tabela
# =========================================
format_table() {
  local output_data="$1"
  local page_size="${2:-20}"
  local use_alternating_colors="${3:-true}"  # Padrão: true (cor alternada ativa)
  
  # Verifica se há dados
  if [[ -z "$output_data" ]]; then
    echo -e "${GRAY}Nenhum resultado encontrado.${NC}"
    return 1
  fi
  
  # Conta número de colunas primeiro
  local first_line=$(echo "$output_data" | head -n 1)
  IFS=$'\t' read -ra HEADER_FIELDS <<< "$first_line"
  local num_columns=${#HEADER_FIELDS[@]}
  
  # Calcula larguras das colunas considerando o número de colunas
  local terminal_width=$(tput cols 2>/dev/null || echo 80)
  
  # Calcula espaço necessário para bordas e separadores
  # Estrutura: │ espaço conteúdo espaço │ espaço conteúdo espaço │
  # Para N colunas: │ (1) + N * (espaço(1) + conteúdo + espaço(1) + │(1)) = 1 + N * 3 + soma(larguras)
  # Overhead fixo por coluna: 3 caracteres (espaço antes + espaço depois + │ separador)
  # Overhead total fixo: 1 (│ inicial) + N * 3
  # Nota: A última coluna também tem │ no final, então são N separadores │
  local border_overhead=$((1 + num_columns * 3))
  
  # Espaço disponível para conteúdo das colunas
  local available_width=$((terminal_width - border_overhead))
  
  # Calcula larguras sem limite primeiro para ver tamanho real necessário
  local widths_str=$(calculate_column_widths "$output_data" "9999")
  # Usa método compatível ao invés de readarray
  widths=()
  local total_min_width=0
  while IFS= read -r width_val; do
    if [[ -n "$width_val" ]]; then
      widths+=("$width_val")
      total_min_width=$((total_min_width + width_val))
    fi
  done <<< "$widths_str"
  
  # Calcula espaço total necessário (larguras + overhead)
  local total_needed_width=$((total_min_width + border_overhead))
  
  # Se o espaço necessário é menor que o disponível, expande as colunas proporcionalmente
  if [[ $total_needed_width -lt $terminal_width && $total_min_width -gt 0 ]]; then
    # Usa 95% do terminal para distribuir entre as colunas
    local target_total_width=$((terminal_width * 95 / 100))
    local target_content_width=$((target_total_width - border_overhead))
    
    if [[ $target_content_width -gt $total_min_width ]]; then
      # Expande proporcionalmente
      local scale_factor=$((target_content_width * 100 / total_min_width))
      
      for i in "${!widths[@]}"; do
        local scaled_width=$((widths[$i] * scale_factor / 100))
        widths[$i]=$scaled_width
      done
    fi
  fi
  
  # Aplica limite máximo apenas se necessário (para evitar colunas extremamente largas)
  # Limite mais generoso baseado no número de colunas
  local absolute_max
  if [[ $num_columns -eq 1 ]]; then
    absolute_max=$((terminal_width - border_overhead))
  elif [[ $num_columns -le 3 ]]; then
    absolute_max=80
  elif [[ $num_columns -le 5 ]]; then
    absolute_max=50
  else
    absolute_max=30
  fi
  
  for i in "${!widths[@]}"; do
    if [[ ${widths[$i]} -gt $absolute_max ]]; then
      widths[$i]=$absolute_max
    fi
    # Garante mínimo de 10 caracteres
    if [[ ${widths[$i]} -lt 10 ]]; then
      widths[$i]=10
    fi
  done
  
  # Processa dados linha por linha
  local all_lines=()
  local line_num=0
  
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      all_lines+=("$line")
      line_num=$((line_num + 1))
    fi
  done <<< "$output_data"
  
  local total_lines=${#all_lines[@]}
  local data_lines=$((total_lines - 1))  # Exclui cabeçalho
  
  # Determina se deve usar paginação ou exibir tudo de uma vez
  local no_pagination=false
  if [[ $page_size -eq 0 ]] || [[ $page_size -gt 99999 ]]; then
    no_pagination=true
    page_size=$data_lines  # Define page_size como total de linhas para exibir tudo
  fi
  
  local total_pages=1
  if [[ $data_lines -gt 0 && "$no_pagination" == false ]]; then
    total_pages=$(( (data_lines + page_size - 1) / page_size ))
  fi
  
  # Função auxiliar para desenhar linha de borda
  draw_border() {
    local char="$1"  # ┌, ├, ou └
    local mid_char="$2"  # ┬, ┼, ou ┴
    local end_char="$3"  # ┐, ┤, ou ┘
    
    echo -ne "${WHITE}$char"
    for i in $(seq 0 $((num_columns - 1))); do
      # Cada coluna tem: 1 espaço antes + conteúdo + 1 espaço depois = widths[$i] + 2
      for j in $(seq 1 $((${widths[$i]} + 2))); do
        echo -ne "─"
      done
      if [[ $i -lt $((num_columns - 1)) ]]; then
        echo -ne "$mid_char"
      fi
    done
    echo -e "${NC}$end_char"
  }
  
  # Função auxiliar para formatar célula
  format_cell() {
    local value="$1"
    local width="$2"
    local align="$3"  # "left" ou "right"
    
    # Trunca se muito longo (garante que width seja pelo menos 3)
    if [[ ${#value} -gt $width && $width -ge 3 ]]; then
      value="${value:0:$((width - 3))}..."
    elif [[ ${#value} -gt $width && $width -lt 3 ]]; then
      # Se width for muito pequeno, trunca para o tamanho máximo possível
      if [[ $width -gt 0 ]]; then
        value="${value:0:$((width - 1))}."
      else
        value=""
      fi
    fi
    
    if [[ "$align" == "right" ]]; then
      printf "%*s" "$width" "$value"
    else
      printf "%-*s" "$width" "$value"
    fi
  }
  
  # Loop de paginação (ou exibição única se no_pagination=true)
  local current_page=1
  local start_data_line=1  # Começa na linha 1 (pula cabeçalho na linha 0)
  
  while [[ $current_page -le $total_pages ]]; do
    # Desenha borda superior
    draw_border "┌" "┬" "┐"
    
    # Cabeçalho com cor destacada
    echo -ne "${WHITE}│${NC}"  # Borda esquerda primeiro (branca)
    echo -ne "\033[44m\033[97m"  # Aplica cor após a borda
    for i in $(seq 0 $((num_columns - 1))); do
      local header_val="${HEADER_FIELDS[$i]}"
      echo -ne " "
      format_cell "$header_val" "${widths[$i]}" "left"
      if [[ $i -eq $((num_columns - 1)) ]]; then
        # Última coluna: reseta cor antes do │ final
        echo -ne " \033[0m${WHITE}│${NC}"
      else
        echo -ne " ${WHITE}│${NC}"
      fi
    done
    echo  # Nova linha
    
    # Separador cabeçalho
    draw_border "├" "┼" "┤"
    
    # Linhas de dados
    local end_data_line=$((start_data_line + page_size - 1))
    if [[ $end_data_line -ge $total_lines ]]; then
      end_data_line=$((total_lines - 1))
    fi
    
    local displayed_count=0
    for line_idx in $(seq $start_data_line $end_data_line); do
      if [[ $line_idx -lt $total_lines ]]; then
        local data_line="${all_lines[$line_idx]}"
        IFS=$'\t' read -ra FIELDS <<< "$data_line"
        
        # Imprime borda esquerda primeiro (branca)
        echo -ne "${WHITE}│${NC}"
        
        # Aplica cor alternada se habilitado
        local has_bg_color=false
        if [[ "$use_alternating_colors" == "true" && $((displayed_count % 2)) -eq 1 ]]; then
          has_bg_color=true
        fi
        
        for i in $(seq 0 $((num_columns - 1))); do
          # Aplica cor de fundo e texto branco no início de cada célula
          if [[ "$has_bg_color" == true ]]; then
            echo -ne "\033[48;5;240m\033[37m"  # Fundo cinza + texto branco
          else
            echo -ne "\033[37m"  # Apenas texto branco
          fi
          
          local field_val="${FIELDS[$i]:-}"
          local col_type=$(detect_column_type "$field_val")
          local align="left"
          if [[ "$col_type" == "numeric" ]]; then
            align="right"
          fi
          
          echo -ne " "
          format_cell "$field_val" "${widths[$i]}" "$align"
          
          # Reseta cores antes da borda
          echo -ne " \033[0m${WHITE}│${NC}"
        done
        echo  # Nova linha
        displayed_count=$((displayed_count + 1))
      fi
    done
    
    # Borda inferior
    draw_border "└" "┴" "┘"
    
    # Informação de paginação (apenas se não estiver em modo sem paginação e houver múltiplas páginas)
    if [[ "$no_pagination" == false && $total_pages -gt 1 ]]; then
      echo -e "${GRAY}[Página ${current_page}/${total_pages}] - Pressione Enter para próxima página, 'q' para sair${NC}"
      
      # Aguarda input
      read -r user_input
      
      if [[ "$user_input" == "q" || "$user_input" == "Q" ]]; then
        break
      fi
      
      start_data_line=$((start_data_line + page_size))
      current_page=$((current_page + 1))
    else
      break
    fi
  done
  
  return 0
}

# =========================================
# CONFIGURAÇÃO DO READLINE PARA HISTÓRICO ISOLADO
# O histórico é limpo a cada inicialização, mantendo apenas a sessão atual
# =========================================
# Salva o histórico do bash atual
_OLD_HISTFILE="$HISTFILE"
_OLD_HISTSIZE="$HISTSIZE"

# Configura histórico isolado apenas para este script
export HISTFILE="$HISTORY_FILE"
export HISTSIZE=1000
export HISTFILESIZE=1000
export HISTCONTROL=ignoredups:ignorespace:erasedups
# Desabilita histórico durante execução do script para evitar captura de linhas do script
set +o history

# Limpa o arquivo de histórico para começar sessão limpa
# Cada sessão mantém apenas seu próprio histórico
if [[ -f "$HISTORY_FILE" ]]; then
  > "$HISTORY_FILE"
fi

# =========================================
# LOOP PRINCIPAL
# =========================================
# Habilita histórico apenas quando o loop principal começar
set -o history
history -c

while true; do
  # Configura PS1 com códigos ANSI envolvidos em \[ \] 
  export PS1="\[${GREEN}\]spanner> \[${WHITE}\]"
  
  # Lê primeira linha para detectar tipo de comando
  if ! IFS= read -r -e -p "$(printf "${GREEN}spanner> ${WHITE}")" FIRST_LINE; then
    # Desabilita histórico antes de sair
    set +o history
    # Restaura histórico original antes de sair
    export HISTFILE="$_OLD_HISTFILE"
    export HISTSIZE="$_OLD_HISTSIZE"
    clear
    echo " Encerrando Spanner Shell..."
    exit 0
  fi
  
  echo -ne "${NC}"
  
  # Remove espaços e códigos ANSI da primeira linha
  FIRST_LINE=$(printf '%s' "$FIRST_LINE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  FIRST_LINE=$(clean_ansi "$FIRST_LINE")
  FIRST_LINE=$(clean_ansi "$FIRST_LINE")
  
  # Ignora linhas vazias
  if [[ -z "${FIRST_LINE// }" ]]; then
    continue
  fi
  
  # Detecta se é comando especial (começa com \) ou comando de controle
  if [[ "$FIRST_LINE" =~ ^\\ ]] || \
     [[ "$FIRST_LINE" == "exit" ]] || \
     [[ "$FIRST_LINE" == "clear" ]] || \
     [[ "$FIRST_LINE" == "\help" ]] || \
     [[ "$FIRST_LINE" == "\h" ]]; then
    # Comando especial: linha única
    SQL="$FIRST_LINE"
  else
    # Comando SQL: permite multi-linha
    # Remove espaços do final e verifica se termina com ;
    FIRST_LINE_TRIMMED=$(echo "$FIRST_LINE" | sed 's/[[:space:]]*$//')
    if [[ "$FIRST_LINE_TRIMMED" == *";" ]]; then
      # Já termina com ; - executa imediatamente
      SQL=$(echo "$FIRST_LINE_TRIMMED" | sed 's/[[:space:]]*;[[:space:]]*$//')
    else
      # Continua lendo até encontrar ;
      SQL_BUFFER="$FIRST_LINE"
      while true; do
        if ! IFS= read -r -e -p "$(printf "${GRAY}    ... ${WHITE}")" NEXT_LINE; then
          # Se EOF (Ctrl+D), cancela
          SQL=""
          break
        fi
        echo -ne "${NC}"
        
        # Remove espaços e códigos ANSI
        NEXT_LINE=$(printf '%s' "$NEXT_LINE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        NEXT_LINE=$(clean_ansi "$NEXT_LINE")
        NEXT_LINE=$(clean_ansi "$NEXT_LINE")
        
        # Se linha vazia, adiciona espaço e continua
        if [[ -z "$NEXT_LINE" ]]; then
          SQL_BUFFER+=" "
          continue
        fi
        
        # Adiciona linha ao buffer
        SQL_BUFFER+=" $NEXT_LINE"
        
        # Remove espaços do final e verifica se termina com ;
        SQL_BUFFER_TRIMMED=$(echo "$SQL_BUFFER" | sed 's/[[:space:]]*$//')
        if [[ "$SQL_BUFFER_TRIMMED" == *";" ]]; then
          # Remove ; final
          SQL=$(echo "$SQL_BUFFER_TRIMMED" | sed 's/[[:space:]]*;[[:space:]]*$//')
          break
        fi
      done
      
      # Se SQL vazio (cancelado), continua loop
      if [[ -z "$SQL" ]]; then
        continue
      fi
    fi
  fi
  
  # Remove espaços em branco no início e fim do SQL final
  SQL=$(printf '%s' "$SQL" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Ignora comandos vazios após limpeza
  if [[ -z "${SQL// }" ]]; then
    continue
  fi

  if [ "$SQL" == "exit" ]; then
    # Salva histórico antes de sair
    history -w "$HISTORY_FILE"
    # Desabilita histórico antes de sair
    set +o history
    clear
    echo "✅ Encerrando Spanner Shell..."
    exit 0
  fi

  # HELP
  if [[ "$SQL" == "\help" || "$SQL" == "\h" ]]; then
    echo -e "${WHITE}"
    echo "Comandos disponíveis:"
    echo "  \\t                             → Lista tabelas"
    echo "  \\d <tabela>                    → Describe tabela"
    echo "  \\n <tabela>                    → Conta registros de uma tabela"
    echo "  \\s <tabela>                    → Mostra registros de exemplo (padrão: 10)"
    echo "  \\l <tabela> [n] [coluna]       → Mostra últimos N registros (padrão: 10, ordenado por PK ou coluna)"
    echo "  \\f <tabela> [n] [coluna]       → Monitora novos registros a cada 5 segundos"
    echo "  \\g <tabela>                    → Gera DML de exemplo (INSERT, UPDATE, SELECT, DELETE)"
    echo "  \\df <tabela> <id1> <id2>       → Compara dois registros e mostra diferenças"
    echo "  \\dd <tabela>                   → DDL de uma tabela específica"
    echo "  \\da                            → DDL completo"
    echo "  \\k <tabela>                    → Exibe a Primary Key da tabela"
    echo "  \\i <tabela>                    → Lista todos os índices da tabela"
    echo "  \\c                             → Exibe as configurações"
    echo "  \\im                            → Importa o conteudo de um arquivo sql com instruções DML"
    echo "  \\id                            → Importa o conteudo de um arquivo sql com instruções DDL"
    echo "  \\e <query> --format csv|json --output <arquivo> → Exporta resultados de query para CSV ou JSON"
    echo "  \\p <query> [--page-size <n>]   → Exibe resultados em tabela formatada com paginação"
    echo "  \\r <n> <cmd>                   → Executa comando N vezes"
    echo "  \\hi [n]                        → Exibe últimos N comandos (padrão: 20)"
    echo "  \\hc                            → Limpa o histórico"
    echo "  clear                          → Limpar tela"
    echo "  exit                           → Sair"
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \hc (deve ser verificado antes de \hi)
  if [[ "$SQL" == "\\hc" ]]; then
    > "$HISTORY_FILE"
    history -c
    echo -e "${GREEN}✅ Histórico limpo com sucesso!${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \hi
  if [[ "$SQL" =~ ^\\hi($|[[:space:]]+) ]]; then
    # Verifica se é para limpar
    if [[ "$SQL" =~ ^\\hi[[:space:]]+clear ]]; then
      > "$HISTORY_FILE"
      history -c
      echo -e "${GREEN}✅ Histórico limpo com sucesso!${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Extrai número de linhas (padrão: 20)
    num_lines=20
    if [[ "$SQL" =~ ^\\hi[[:space:]]+([0-9]+) ]]; then
      num_lines="${BASH_REMATCH[1]}"
    fi
    
    echo -e "${WHITE}"
    echo "Últimos ${num_lines} comandos:"
    echo "----------------------------------------"
    # Mostra últimos N comandos do histórico
    history | tail -n $((num_lines + 1)) | head -n $num_lines | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//'
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \c
  if [[ "$SQL" == "\c" ]]; then
    echo -e "${WHITE}"
    echo "Configurações:"
    echo "  Profile:  ${SELECTED_NAME}"
    echo "  Type:     ${TYPE}"
    echo "  Project:  ${PROJECT_ID}"
    echo "  Instance: ${INSTANCE_ID}"
    echo "  Database: ${DATABASE_ID}"
    if [[ -n "$ENDPOINT" ]]; then
      echo "  Endpoint: ${ENDPOINT}"
    fi
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \t
  if [[ "$SQL" == "\t" ]]; then
    TABLE_OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT table_name FROM information_schema.tables WHERE table_schema = '' ORDER BY table_name;" 2>&1)

    STATUS=$?

    if [ $STATUS -ne 0 ]; then
      ERROR_MSG=$(echo "$TABLE_OUTPUT" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
      if [ -n "$ERROR_MSG" ]; then
        FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
        echo -e "${RED}❌ Erro: ${FORMATTED_ERROR}${NC}"
      else
        echo -e "${RED}❌ Erro ao listar tabelas.${NC}"
      fi
    else
      if [[ -n "$TABLE_OUTPUT" && ! "$TABLE_OUTPUT" =~ ^[[:space:]]*$ ]]; then
        format_table "$TABLE_OUTPUT" 0 false
      else
        echo -e "${GRAY}Nenhuma tabela encontrada.${NC}"
      fi
    fi

    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \da (deve ser verificado antes de \dd <tabela>)
  if [[ "$SQL" == "\\da" ]] || [[ "$SQL" =~ ^\\da[[:space:]]*$ ]]; then
    echo -e "${WHITE}"
    gcloud spanner databases ddl describe ${DATABASE_ID} \
      --instance=${INSTANCE_ID}
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \dd <tabela>
  if [[ "$SQL" =~ ^\\dd[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    echo -e "${WHITE}"
    DDL_OUTPUT=$(gcloud spanner databases ddl describe ${DATABASE_ID} \
      --instance=${INSTANCE_ID} 2>/dev/null)
    
    # Extrai o DDL da tabela específica
    FOUND=false
    IN_TABLE=false
    while IFS= read -r line; do
      if [[ "$line" =~ CREATE\ TABLE.*${TABLE_NAME} ]]; then
        IN_TABLE=true
        FOUND=true
        echo "$line"
      elif [[ "$IN_TABLE" == true ]]; then
        if [[ "$line" =~ ^CREATE\ (TABLE|INDEX) ]] && [[ ! "$line" =~ ${TABLE_NAME} ]]; then
          break
        fi
        echo "$line"
      fi
    done <<< "$DDL_OUTPUT"
    
    if [[ "$FOUND" == false ]]; then
      echo "Tabela '${TABLE_NAME}' não encontrada no DDL."
    fi
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \d <tabela>
  if [[ "$SQL" =~ ^\\d[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    COLUMNS_OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT column_name, spanner_type, is_nullable FROM information_schema.columns WHERE table_name = '${TABLE_NAME}' ORDER BY ordinal_position;" 2>&1)

    STATUS=$?

    if [ $STATUS -ne 0 ]; then
      ERROR_MSG=$(echo "$COLUMNS_OUTPUT" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
      if [ -n "$ERROR_MSG" ]; then
        FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
        echo -e "${RED}❌ Erro: ${FORMATTED_ERROR}${NC}"
      else
        echo -e "${RED}❌ Erro ao descrever tabela '${TABLE_NAME}'.${NC}"
      fi
    else
      if [[ -n "$COLUMNS_OUTPUT" && ! "$COLUMNS_OUTPUT" =~ ^[[:space:]]*$ ]]; then
        format_table "$COLUMNS_OUTPUT" 0 false
      else
        echo -e "${GRAY}Tabela '${TABLE_NAME}' não encontrada ou não possui colunas.${NC}"
      fi
    fi

    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \n <tabela>
  if [[ "$SQL" =~ ^\\n[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    echo -e "${WHITE}"
    echo "Contando registros na tabela '${TABLE_NAME}'..."
    gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT COUNT(*) as total FROM ${TABLE_NAME};"
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \s <tabela> [n]
  if [[ "$SQL" =~ ^\\s[[:space:]]+([a-zA-Z0-9_]+)([[:space:]]+([0-9]+))?$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    SAMPLE_SIZE="${BASH_REMATCH[3]:-10}"  # Padrão: 10 se não especificado
    
    # Valida tamanho do sample
    if [[ "$SAMPLE_SIZE" -lt 1 || "$SAMPLE_SIZE" -gt 1000 ]]; then
      echo -e "${RED}❌ Tamanho do sample deve estar entre 1 e 1000${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Executa query e captura saída
    TABLE_OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT * FROM ${TABLE_NAME} LIMIT ${SAMPLE_SIZE};" 2>&1)
    
    STATUS=$?
    
    if [ $STATUS -ne 0 ]; then
      ERROR_MSG=$(echo "$TABLE_OUTPUT" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
      if [ -n "$ERROR_MSG" ]; then
        FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
        echo -e "${RED}❌ Erro: ${FORMATTED_ERROR}${NC}"
      else
        echo -e "${RED}❌ Erro ao executar query na tabela '${TABLE_NAME}'.${NC}"
      fi
    else
      if [[ -n "$TABLE_OUTPUT" && ! "$TABLE_OUTPUT" =~ ^[[:space:]]*$ ]]; then
        echo -e "${WHITE}"
        echo "Mostrando ${SAMPLE_SIZE} registros da tabela '${TABLE_NAME}':"
        echo "----------------------------------------"
        format_table "$TABLE_OUTPUT" 0 true
      else
        echo -e "${GRAY}Nenhum registro encontrado na tabela '${TABLE_NAME}'.${NC}"
      fi
    fi
    
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \f <tabela> [n] [coluna] (deve ser verificado antes de \l básico)
  if [[ "$SQL" =~ ^\\f[[:space:]]+([a-zA-Z0-9_]+)([[:space:]]+([0-9]+))?([[:space:]]+([a-zA-Z0-9_]+))?$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    TAIL_SIZE="${BASH_REMATCH[3]:-10}"
    ORDER_COLUMN="${BASH_REMATCH[5]}"
    
    # Valida tamanho
    if [[ "$TAIL_SIZE" -lt 1 || "$TAIL_SIZE" -gt 1000 ]]; then
      echo -e "${RED}❌ Número de registros deve estar entre 1 e 1000${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Determina coluna de ordenação
    if [[ -z "$ORDER_COLUMN" ]]; then
      ORDER_COLUMN=$(get_default_order_column "$TABLE_NAME")
      if [[ -z "$ORDER_COLUMN" ]]; then
        echo -e "${RED}❌ Não foi possível determinar coluna de ordenação para a tabela '${TABLE_NAME}'${NC}"
        save_to_history "$SQL"
        continue
      fi
    else
      # Valida se coluna existe
      if ! validate_column_exists "$TABLE_NAME" "$ORDER_COLUMN"; then
        echo -e "${RED}❌ Coluna '${ORDER_COLUMN}' não encontrada na tabela '${TABLE_NAME}'${NC}"
        save_to_history "$SQL"
        continue
      fi
    fi
    
    # Obtém tipo da coluna de ordenação
    COLUMN_TYPE=$(get_column_type "$TABLE_NAME" "$ORDER_COLUMN")
    
    echo -e "${WHITE}"
    echo "Monitorando novos registros na tabela '${TABLE_NAME}' (a cada 5 segundos)..."
    echo "Ordenado por: ${ORDER_COLUMN} (${COLUMN_TYPE})"
    echo "Pressione Ctrl+C para parar"
    echo "----------------------------------------"
    echo -e "${NC}"
    
    # Variável para armazenar último valor visto
    LAST_VALUE=""
    FIRST_RUN=true
    
    # Handler para interrupção
    tail_interrupted=false
    tail_interrupt_handler() {
      tail_interrupted=true
      echo ""
      echo -e "${GREEN}✅ Monitoramento interrompido${NC}"
    }
    trap tail_interrupt_handler SIGINT
    
    while true; do
      # Verifica se foi interrompido
      if [[ "$tail_interrupted" == true ]]; then
        trap - SIGINT  # Remove o handler
        break
      fi
      
      # Monta query SQL
      if [[ "$FIRST_RUN" == true ]]; then
        # Primeira execução: mostra últimos N registros e obtém o maior valor
        SQL_QUERY="SELECT * FROM ${TABLE_NAME} ORDER BY ${ORDER_COLUMN} DESC LIMIT ${TAIL_SIZE};"
        FIRST_RUN=false
      else
        # Execuções subsequentes: mostra apenas registros novos
        if [[ -n "$LAST_VALUE" ]]; then
          # Monta comparação baseada no tipo
          case "$COLUMN_TYPE" in
            "STRING"|"BYTES"|"DATE"|"TIMESTAMP")
              SQL_QUERY="SELECT * FROM ${TABLE_NAME} WHERE ${ORDER_COLUMN} > '${LAST_VALUE}' ORDER BY ${ORDER_COLUMN} DESC LIMIT ${TAIL_SIZE};"
              ;;
            "INT64"|"FLOAT64")
              SQL_QUERY="SELECT * FROM ${TABLE_NAME} WHERE ${ORDER_COLUMN} > ${LAST_VALUE} ORDER BY ${ORDER_COLUMN} DESC LIMIT ${TAIL_SIZE};"
              ;;
            *)
              # Para outros tipos, tenta com aspas
              SQL_QUERY="SELECT * FROM ${TABLE_NAME} WHERE ${ORDER_COLUMN} > '${LAST_VALUE}' ORDER BY ${ORDER_COLUMN} DESC LIMIT ${TAIL_SIZE};"
              ;;
          esac
        else
          SQL_QUERY="SELECT * FROM ${TABLE_NAME} ORDER BY ${ORDER_COLUMN} DESC LIMIT ${TAIL_SIZE};"
        fi
      fi
      
      # Executa query
      OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
        --instance=${INSTANCE_ID} \
        --quiet \
        --sql="$SQL_QUERY" 2>&1)
      
      STATUS=$?
      
      if [ $STATUS -eq 0 ]; then
        # Verifica se há resultados
        if [[ -n "$OUTPUT" && ! "$OUTPUT" =~ ^[[:space:]]*$ ]]; then
          # Obtém o maior valor da coluna de ordenação dos resultados atuais
          # Faz uma query simples que retorna apenas o maior valor atual
          MAX_VALUE_QUERY="SELECT ${ORDER_COLUMN} FROM ${TABLE_NAME} ORDER BY ${ORDER_COLUMN} DESC LIMIT 1;"
          MAX_OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
            --instance=${INSTANCE_ID} \
            --quiet \
            --sql="$MAX_VALUE_QUERY" 2>/dev/null)
          
          # Extrai o valor máximo (pula cabeçalho)
          NEW_LAST_VALUE=""
          if [[ -n "$MAX_OUTPUT" ]]; then
            MAX_LINE=$(echo "$MAX_OUTPUT" | grep -v "^${ORDER_COLUMN}" | grep -v "^$" | head -n 1)
            if [[ -n "$MAX_LINE" ]]; then
              NEW_LAST_VALUE=$(echo "$MAX_LINE" | awk '{print $1}' | sed "s/'//g" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            fi
          fi
          
          # Mostra resultados se for primeira execução ou se há novos registros
          if [[ -z "$LAST_VALUE" ]]; then
            # Primeira execução: mostra todos os últimos N registros
            format_table "$OUTPUT" 0 true
            if [[ -n "$NEW_LAST_VALUE" && "$NEW_LAST_VALUE" != "NULL" ]]; then
              LAST_VALUE="$NEW_LAST_VALUE"
            fi
          elif [[ -n "$NEW_LAST_VALUE" && "$NEW_LAST_VALUE" != "NULL" && "$NEW_LAST_VALUE" != "$LAST_VALUE" ]]; then
            # Execuções subsequentes: mostra apenas se houver novos registros
            echo -e "${GREEN}[$(date +%H:%M:%S)] Novos registros encontrados:${NC}"
            format_table "$OUTPUT" 0 true
            LAST_VALUE="$NEW_LAST_VALUE"
          fi
        fi
      else
        # Em caso de erro, tenta extrair mensagem
        ERROR_MSG=$(echo "$OUTPUT" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
        if [[ -n "$ERROR_MSG" ]]; then
          FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
          echo -e "${RED}❌ Erro: ${FORMATTED_ERROR}${NC}"
        else
          echo -e "${RED}❌ Erro ao executar query${NC}"
        fi
        # Continua mesmo com erro
      fi
      
      # Aguarda 5 segundos
      sleep 5
    done
    
    trap - SIGINT  # Remove o handler ao sair
    save_to_history "$SQL"
    continue
  fi

  # \l <tabela> [n] [coluna]
  if [[ "$SQL" =~ ^\\l[[:space:]]+([a-zA-Z0-9_]+)([[:space:]]+([0-9]+))?([[:space:]]+([a-zA-Z0-9_]+))?$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    TAIL_SIZE="${BASH_REMATCH[3]:-10}"
    ORDER_COLUMN="${BASH_REMATCH[5]}"
    
    # Valida tamanho
    if [[ "$TAIL_SIZE" -lt 1 || "$TAIL_SIZE" -gt 1000 ]]; then
      echo -e "${RED}❌ Número de registros deve estar entre 1 e 1000${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Determina coluna de ordenação
    if [[ -z "$ORDER_COLUMN" ]]; then
      ORDER_COLUMN=$(get_default_order_column "$TABLE_NAME")
      if [[ -z "$ORDER_COLUMN" ]]; then
        echo -e "${RED}❌ Não foi possível determinar coluna de ordenação para a tabela '${TABLE_NAME}'${NC}"
        save_to_history "$SQL"
        continue
      fi
    else
      # Valida se coluna existe
      if ! validate_column_exists "$TABLE_NAME" "$ORDER_COLUMN"; then
        echo -e "${RED}❌ Coluna '${ORDER_COLUMN}' não encontrada na tabela '${TABLE_NAME}'${NC}"
        save_to_history "$SQL"
        continue
      fi
    fi
    
    # Executa query e captura saída
    TABLE_OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT * FROM ${TABLE_NAME} ORDER BY ${ORDER_COLUMN} DESC LIMIT ${TAIL_SIZE};" 2>&1)
    
    STATUS=$?
    
    if [ $STATUS -ne 0 ]; then
      ERROR_MSG=$(echo "$TABLE_OUTPUT" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
      if [ -n "$ERROR_MSG" ]; then
        FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
        echo -e "${RED}❌ Erro: ${FORMATTED_ERROR}${NC}"
      else
        echo -e "${RED}❌ Erro ao executar query na tabela '${TABLE_NAME}'.${NC}"
      fi
    else
      if [[ -n "$TABLE_OUTPUT" && ! "$TABLE_OUTPUT" =~ ^[[:space:]]*$ ]]; then
        echo -e "${WHITE}"
        echo "Mostrando últimos ${TAIL_SIZE} registros da tabela '${TABLE_NAME}' (ordenado por ${ORDER_COLUMN}):"
        echo "----------------------------------------"
        format_table "$TABLE_OUTPUT" 0 true
      else
        echo -e "${GRAY}Nenhum registro encontrado na tabela '${TABLE_NAME}'.${NC}"
      fi
    fi
    
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \g <tabela>
  if [[ "$SQL" =~ ^\\g[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    generate_dml_examples "$TABLE_NAME"
    save_to_history "$SQL"
    continue
  fi

# =========================================
# ✅ COMANDO: \repeat <n> <comando>
# =========================================
if [[ "$SQL" =~ ^\\r[[:space:]]+([0-9]+)[[:space:]]+(.+)$ ]]; then
  REPEAT_COUNT="${BASH_REMATCH[1]}"
  REPEAT_CMD="${BASH_REMATCH[2]}"
  
  # Remove códigos ANSI do comando
  REPEAT_CMD=$(clean_ansi "$REPEAT_CMD")
  REPEAT_CMD=$(clean_ansi "$REPEAT_CMD")
  # Remove espaços no início e fim
  REPEAT_CMD=$(printf '%s' "$REPEAT_CMD" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  # Remove aspas externas se existirem (simples ou duplas)
  if [[ "$REPEAT_CMD" =~ ^\"(.*)\"$ ]]; then
    REPEAT_CMD="${BASH_REMATCH[1]}"
  elif [[ "$REPEAT_CMD" =~ ^\'(.*)\'$ ]]; then
    REPEAT_CMD="${BASH_REMATCH[1]}"
  fi
  
  # Valida número de repetições
  if [[ "$REPEAT_COUNT" -lt 1 || "$REPEAT_COUNT" -gt 100 ]]; then
    echo -e "${RED}❌ Número de repetições deve estar entre 1 e 100${NC}"
    save_to_history "$SQL"
    continue
  fi
  
  echo -e "${WHITE}"
  echo "Executando comando ${REPEAT_COUNT} vez(es):"
  echo "----------------------------------------"
  
  # Mostra o comando completo na primeira vez (truncado se muito longo)
  if [[ ${#REPEAT_CMD} -gt 80 ]]; then
    echo -e "${GRAY}Comando:${NC} ${WHITE}${REPEAT_CMD:0:77}...${NC}"
  else
    echo -e "${GRAY}Comando:${NC} ${WHITE}${REPEAT_CMD}${NC}"
  fi
  echo
  
  for ((i=1; i<=REPEAT_COUNT; i++)); do
    echo -e "${GRAY}[${i}/${REPEAT_COUNT}]${NC}"
    
    # Executa o comando como SQL (assume que é uma query SQL)
    echo -e "${WHITE}"
    OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="$REPEAT_CMD" 2>&1)
    
    STATUS=$?
    
    if [ $STATUS -ne 0 ]; then
      ERROR_MSG=$(echo "$OUTPUT" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
      if [ -n "$ERROR_MSG" ]; then
        FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
        echo -e "${RED}❌ Erro: ${FORMATTED_ERROR}${NC}"
      else
        FORMATTED_ERROR=$(format_error_message "$OUTPUT")
        echo -e "${RED}❌ Erro: ${FORMATTED_ERROR}${NC}"
      fi
    else
      echo "$OUTPUT"
    fi
    echo -e "${NC}"
    
    # Adiciona separador entre execuções (exceto na última)
    if [[ $i -lt $REPEAT_COUNT ]]; then
      echo "----------------------------------------"
    fi
  done
  
  echo
  save_to_history "$SQL"
  continue
fi

# =========================================
# ✅ COMANDO: \import-ddl <arquivo.sql>
# =========================================
if [[ "$SQL" =~ ^\\id($|[[:space:]]+) ]]; then

  # Remove o comando "\id" e captura apenas o path
  FILE_PATH="$(echo "$SQL" | sed 's/^\\id[[:space:]]*//')"

  # ✅ 1. Valida se o caminho foi informado
  if [[ -z "$FILE_PATH" ]]; then
    echo -e "${RED}❌ Uso correto: \\id <caminho-do-arquivo.sql>${NC}"
    continue
  fi

  # ✅ 2. Valida se o arquivo existe
  if [[ ! -f "$FILE_PATH" ]]; then
    echo -e "${RED}❌ Arquivo não encontrado: ${FILE_PATH}${NC}"
    continue
  fi

  # ✅ 3. Executa o arquivo
  echo -e "${WHITE}📂 Carregando arquivo: ${FILE_PATH}${NC}"
  echo

  gcloud spanner databases ddl update ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --ddl="$(cat "$FILE_PATH")"

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Arquivo importado com sucesso!${NC}"
  else
    echo -e "${RED}❌ Erro ao executar o arquivo.${NC}"
  fi

  save_to_history "$SQL"
  continue
fi

# =========================================
# ✅ COMANDO: \import <arquivo.sql>
# =========================================
if [[ "$SQL" =~ ^\\im($|[[:space:]]+) ]]; then

  # Remove o comando "\im" e captura apenas o path
  FILE_PATH="$(echo "$SQL" | sed 's/^\\im[[:space:]]*//')"

  # ✅ 1. Valida se o caminho foi informado
  if [[ -z "$FILE_PATH" ]]; then
    echo -e "${RED}❌ Uso correto: \\im <caminho-do-arquivo.sql>${NC}"
    continue
  fi

  # ✅ 2. Valida se o arquivo existe
  if [[ ! -f "$FILE_PATH" ]]; then
    echo -e "${RED}❌ Arquivo não encontrado: ${FILE_PATH}${NC}"
    continue
  fi

  # ✅ 3. Executa o arquivo
  echo -e "${WHITE}📂 Carregando arquivo: ${FILE_PATH}${NC}"
  echo

  gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="$(cat "$FILE_PATH")"

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Arquivo importado com sucesso!${NC}"
  else
    echo -e "${RED}❌ Erro ao executar o arquivo.${NC}"
  fi

  save_to_history "$SQL"
  continue
fi

# =========================================
# ✅ COMANDO: \pk <tabela>
# =========================================
if [[ "$SQL" =~ ^\\k[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
  TABLE_NAME="${BASH_REMATCH[1]}"

  echo -e "${WHITE}🔑 Primary Key da tabela: ${TABLE_NAME}${NC}"
  echo

  OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="
      SELECT column_name
      FROM information_schema.index_columns
      WHERE table_name = '${TABLE_NAME}'
        AND index_type = 'PRIMARY_KEY'
      ORDER BY ordinal_position;
    " 2>&1)

  STATUS=$?

  if [ $STATUS -ne 0 ]; then
    ERROR_MSG=$(echo "$OUTPUT" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')

    if [ -n "$ERROR_MSG" ]; then
      FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
      echo -e "${RED}❌ Erro: ${FORMATTED_ERROR}${NC}"
    else
      echo -e "${RED}❌ Erro ao buscar PK.${NC}"
    fi
    echo
    continue
  fi

  # Remove header do gcloud (se houver)
  PK_COLUMNS=$(echo "$OUTPUT" | tail -n +2)

  if [ -z "$PK_COLUMNS" ]; then
    echo -e "${GRAY}⚠️  Nenhuma PK encontrada para a tabela '${TABLE_NAME}'.${NC}"
  else
    echo "$PK_COLUMNS"
  fi

  echo
  continue
fi


# =========================================
# ✅ COMANDO: \indexes <tabela>
# =========================================
if [[ "$SQL" =~ ^\\i[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
  TABLE_NAME="${BASH_REMATCH[1]}"

  echo -e "${WHITE}📑 Índices da tabela: ${TABLE_NAME}${NC}"
  echo

  OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="
      SELECT 
        index_name,
        index_type,
        column_name,
        ordinal_position
      FROM information_schema.index_columns
      WHERE table_name = '${TABLE_NAME}'
      ORDER BY index_name, ordinal_position;
    " 2>&1)

  STATUS=$?

  if [ $STATUS -ne 0 ]; then
    ERROR_MSG=$(echo "$OUTPUT" | sed -n 's/.*\"message\":\"\([^\"]*\)\".*/\1/p')

    if [ -n "$ERROR_MSG" ]; then
      FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
      echo -e "${RED}❌ Erro: ${FORMATTED_ERROR}${NC}"
    else
      echo -e "${RED}❌ Erro ao buscar índices.${NC}"
    fi

    echo
    continue
  fi

  RESULT=$(echo "$OUTPUT" | tail -n +2)

  if [ -z "$RESULT" ]; then
    echo -e "${GRAY}⚠️  Nenhum índice encontrado para a tabela '${TABLE_NAME}'.${NC}"
    echo
    continue
  fi

  CURRENT_INDEX=""
  echo "$RESULT" | while read -r INDEX_NAME INDEX_TYPE COLUMN_NAME ORDINAL; do
    if [[ "$INDEX_NAME" != "$CURRENT_INDEX" ]]; then
      echo
      echo -e "${GREEN}🔹 Índice: ${INDEX_NAME} (${INDEX_TYPE})${NC}"
      CURRENT_INDEX="$INDEX_NAME"
    fi
    echo "   - ${COLUMN_NAME}"
  done

  echo
  continue
fi

# =========================================
# ✅ COMANDO: \diff <tabela> <id1> <id2>
# =========================================
if [[ "$SQL" =~ ^\\df($|[[:space:]]+) ]]; then

  # Remove o comando "\df" e captura apenas os parâmetros
  PARAMS=$(echo "$SQL" | sed 's/^\\df[[:space:]]*//')

  # ✅ Valida quantidade de parâmetros
  PARAM_COUNT=$(echo "$PARAMS" | wc -w | tr -d ' ')

  if [[ $PARAM_COUNT -ne 3 ]]; then
    echo -e "${RED}❌ Uso correto: \\df <tabela> <id1> <id2>${NC}"
    continue
  fi

  TABLE_NAME=$(echo "$PARAMS" | awk '{print $1}')
  ID1_RAW=$(echo "$PARAMS" | awk '{print $2}')
  ID2_RAW=$(echo "$PARAMS" | awk '{print $3}')

  # Verifica se o jq está instalado
  if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}❌ jq não está instalado.${NC}"
    echo -e "${WHITE}➡️  Instale com:${NC}"
    echo -e "${GRAY}   macOS: brew install jq${NC}"
    echo -e "${GRAY}   Linux: sudo apt-get install jq (ou sudo yum install jq)${NC}"
    continue
  fi

  echo -e "${WHITE}🔍 Comparando registros da tabela: ${TABLE_NAME}${NC}"
  echo "   ID1: ${ID1_RAW}"
  echo "   ID2: ${ID2_RAW}"
  echo

  # =========================================
  # 🔎 DETECTA TIPO DA PK (STRING ou INT64)
  # =========================================
  PK_INFO=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="
      SELECT c.column_name, c.spanner_type
      FROM information_schema.index_columns i
      JOIN information_schema.columns c
        ON i.table_name = c.table_name
       AND i.column_name = c.column_name
      WHERE i.table_name='${TABLE_NAME}'
        AND i.index_type='PRIMARY_KEY'
      ORDER BY i.ordinal_position
      LIMIT 1;
    ")

  PK_COLUMN=$(echo "$PK_INFO" | tail -n +2 | awk '{print $1}')
  PK_TYPE=$(echo "$PK_INFO" | tail -n +2 | awk '{print $2}')

  if [[ -z "$PK_COLUMN" || -z "$PK_TYPE" ]]; then
    echo -e "${RED}❌ Não foi possível detectar a PK da tabela.${NC}"
    continue
  fi

  # =========================================
  # 🔐 AJUSTA FORMATO DO ID CONFORME O TIPO
  # =========================================
  if [[ "$PK_TYPE" == "STRING" ]]; then
    ID1="'${ID1_RAW}'"
    ID2="'${ID2_RAW}'"
  else
    # INT64
    if [[ ! "$ID1_RAW" =~ ^[0-9]+$ || ! "$ID2_RAW" =~ ^[0-9]+$ ]]; then
      echo -e "${RED}❌ A PK é numérica (INT64). Os IDs devem ser números.${NC}"
      continue
    fi
    ID1="${ID1_RAW}"
    ID2="${ID2_RAW}"
  fi

  # =========================================
  # 🔎 OBTÉM NOMES DAS COLUNAS DA TABELA
  # =========================================
  COLUMNS_INFO=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="SELECT column_name FROM information_schema.columns WHERE table_name = '${TABLE_NAME}' ORDER BY ordinal_position;" 2>/dev/null)

  # Extrai nomes das colunas (pula cabeçalho)
  COLUMN_NAMES=()
  FIRST_LINE=true
  while IFS= read -r line; do
    if [[ "$FIRST_LINE" == true ]]; then
      FIRST_LINE=false
      continue
    fi
    if [[ -n "$line" && "$line" != "column_name" ]]; then
      COL_NAME=$(echo "$line" | awk '{print $1}')
      if [[ -n "$COL_NAME" ]]; then
        COLUMN_NAMES+=("$COL_NAME")
      fi
    fi
  done <<< "$COLUMNS_INFO"

  if [[ ${#COLUMN_NAMES[@]} -eq 0 ]]; then
    echo -e "${RED}❌ Não foi possível obter as colunas da tabela.${NC}"
    continue
  fi

  # =========================================
  # 🔎 BUSCA OS DOIS REGISTROS
  # =========================================
  ROW1_RAW=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --format=json \
    --sql="SELECT * FROM ${TABLE_NAME} WHERE ${PK_COLUMN}=${ID1}" 2>&1)

  ROW2_RAW=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --format=json \
    --sql="SELECT * FROM ${TABLE_NAME} WHERE ${PK_COLUMN}=${ID2}" 2>&1)

  # Verifica se houve erro na execução
  if [[ "$ROW1_RAW" =~ "ERROR" ]] || [[ "$ROW2_RAW" =~ "ERROR" ]]; then
    echo -e "${RED}❌ Erro ao buscar registros.${NC}"
    continue
  fi

  # =========================================
  # 🔄 CONVERTE ARRAYS DE VALORES EM OBJETOS JSON
  # O gcloud retorna arrays de valores, precisamos combiná-los com nomes de colunas
  # =========================================
  # Extrai o primeiro array de valores
  ARRAY1=$(echo "$ROW1_RAW" | jq '
    if type == "array" then 
      if length > 0 then .[0] else empty end
    elif type == "object" and has("rows") then 
      if (.rows | length) > 0 then .rows[0] else empty end
    else 
      empty 
    end
  ' 2>/dev/null)

  ARRAY2=$(echo "$ROW2_RAW" | jq '
    if type == "array" then 
      if length > 0 then .[0] else empty end
    elif type == "object" and has("rows") then 
      if (.rows | length) > 0 then .rows[0] else empty end
    else 
      empty 
    end
  ' 2>/dev/null)

  # Verifica se conseguiu extrair os arrays
  if [[ -z "$ARRAY1" || -z "$ARRAY2" || "$ARRAY1" == "null" || "$ARRAY2" == "null" || "$ARRAY1" == "" || "$ARRAY2" == "" ]]; then
    # Verifica se é porque os registros não existem
    ROW1_CHECK=$(echo "$ROW1_RAW" | jq 'if type == "array" then length elif type == "object" and has("rows") then (.rows | length) else 0 end' 2>/dev/null || echo "0")
    ROW2_CHECK=$(echo "$ROW2_RAW" | jq 'if type == "array" then length elif type == "object" and has("rows") then (.rows | length) else 0 end' 2>/dev/null || echo "0")
    
    if [[ "$ROW1_CHECK" == "0" || "$ROW2_CHECK" == "0" ]]; then
      echo -e "${RED}❌ Um ou ambos os registros não existem.${NC}"
    else
      echo -e "${RED}❌ Erro ao processar dados dos registros.${NC}"
    fi
    continue
  fi

  # Constrói objetos JSON combinando nomes de colunas com valores
  # Cria um objeto JSON onde cada chave é o nome da coluna e o valor vem do array
  J1_OBJ="{"
  J2_OBJ="{"
  
  for i in "${!COLUMN_NAMES[@]}"; do
    COL_NAME="${COLUMN_NAMES[$i]}"
    
    # Extrai valor do array na posição i
    VAL1=$(echo "$ARRAY1" | jq -c ".[$i]" 2>/dev/null)
    VAL2=$(echo "$ARRAY2" | jq -c ".[$i]" 2>/dev/null)
    
    # Adiciona vírgula se não for o primeiro campo
    if [[ $i -gt 0 ]]; then
      J1_OBJ+=","
      J2_OBJ+=","
    fi
    
    # Adiciona campo ao objeto JSON
    J1_OBJ+="\"$COL_NAME\":$VAL1"
    J2_OBJ+="\"$COL_NAME\":$VAL2"
  done
  
  J1_OBJ+="}"
  J2_OBJ+="}"

  # Valida se os objetos JSON são válidos
  J1=$(echo "$J1_OBJ" | jq '.' 2>/dev/null)
  J2=$(echo "$J2_OBJ" | jq '.' 2>/dev/null)

  if [[ -z "$J1" || -z "$J2" || "$J1" == "null" || "$J2" == "null" ]]; then
    echo -e "${RED}❌ Erro ao construir objetos JSON para comparação.${NC}"
    continue
  fi

  echo -e "${GREEN}📊 Diferenças encontradas:${NC}"
  echo

  DIFF_FOUND=false

  # Compara cada campo
  for FIELD in "${COLUMN_NAMES[@]}"; do
    # Extrai valores usando jq
    V1=$(echo "$J1" | jq -c --arg field "$FIELD" '.[$field]' 2>/dev/null)
    V2=$(echo "$J2" | jq -c --arg field "$FIELD" '.[$field]' 2>/dev/null)

    # Compara valores (considera null como valor válido)
    if [[ "$V1" != "$V2" ]]; then
      DIFF_FOUND=true
      echo "• ${FIELD}:"
      echo "    ${ID1_RAW} → ${V1}"
      echo "    ${ID2_RAW} → ${V2}"
      echo
    fi
  done

  if [[ "$DIFF_FOUND" == false ]]; then
    echo -e "${GRAY}✅ Registros são idênticos.${NC}"
  fi

  continue
fi
# =========================================
# ✅ COMANDO: \export <query> --format csv|json --output <arquivo>
# =========================================
if [[ "$SQL" =~ ^\\e[[:space:]]+ ]]; then
  # Remove o comando "\e" do início
  export_cmd=$(echo "$SQL" | sed 's/^\\e[[:space:]]*//')
  
  # Extrai query SQL (pode estar entre aspas ou não)
  query=""
  format=""
  output_file=""
  
  # Tenta extrair query entre aspas duplas
  if [[ "$export_cmd" =~ ^\"([^\"]+)\" ]]; then
    query="${BASH_REMATCH[1]}"
    export_cmd=$(echo "$export_cmd" | sed 's/^"[^"]*"[[:space:]]*//')
  # Tenta extrair query entre aspas simples
  elif [[ "$export_cmd" =~ ^\'([^\']+)\' ]]; then
    query="${BASH_REMATCH[1]}"
    export_cmd=$(echo "$export_cmd" | sed "s/^'[^']*'[[:space:]]*//")
  else
    # Query sem aspas - extrai até encontrar --format
    if [[ "$export_cmd" =~ ^([^[:space:]]+[[:space:]]+.*?)[[:space:]]+--format ]]; then
      query=$(echo "$export_cmd" | sed 's/[[:space:]]*--format.*$//')
      export_cmd=$(echo "$export_cmd" | sed 's/^.*[[:space:]]*--format[[:space:]]*//')
    else
      # Query simples sem --format (erro)
      query=""
    fi
  fi
  
  # Extrai --format
  if [[ "$export_cmd" =~ ^(csv|json)[[:space:]]+ ]]; then
    format="${BASH_REMATCH[1]}"
    export_cmd=$(echo "$export_cmd" | sed 's/^[^[:space:]]*[[:space:]]*//')
  elif [[ "$export_cmd" =~ ^--format[[:space:]]+(csv|json)[[:space:]]+ ]]; then
    format="${BASH_REMATCH[1]}"
    export_cmd=$(echo "$export_cmd" | sed 's/^--format[[:space:]]*[^[:space:]]*[[:space:]]*//')
  fi
  
  # Extrai --output
  if [[ "$export_cmd" =~ ^--output[[:space:]]+([^[:space:]]+) ]]; then
    output_file="${BASH_REMATCH[1]}"
  elif [[ "$export_cmd" =~ ^([^[:space:]]+) ]]; then
    # Se não tem --output, assume que o próximo token é o arquivo
    output_file="${BASH_REMATCH[1]}"
  fi
  
  # Validações
  if [[ -z "$query" ]]; then
    echo -e "${RED}❌ Query SQL não informada.${NC}"
    echo -e "${WHITE}Uso: \\e \"<query>\" --format csv|json --output <arquivo>${NC}"
    save_to_history "$SQL"
    continue
  fi
  
  if [[ -z "$format" || ! "$format" =~ ^(csv|json)$ ]]; then
    echo -e "${RED}❌ Formato inválido. Deve ser 'csv' ou 'json'.${NC}"
    save_to_history "$SQL"
    continue
  fi
  
  if [[ -z "$output_file" ]]; then
    echo -e "${RED}❌ Arquivo de saída não informado.${NC}"
    save_to_history "$SQL"
    continue
  fi
  
  # Valida diretório de saída
  output_dir=$(dirname "$output_file")
  if [[ -n "$output_dir" && "$output_dir" != "." ]]; then
    if [[ ! -d "$output_dir" ]]; then
      if ! mkdir -p "$output_dir" 2>/dev/null; then
        echo -e "${RED}❌ Não foi possível criar o diretório: ${output_dir}${NC}"
        save_to_history "$SQL"
        continue
      fi
    fi
  fi
  
  # Verifica se arquivo já existe
  if [[ -f "$output_file" ]]; then
    echo -e "${GRAY}⚠️  Arquivo já existe: ${output_file}${NC}"
    echo -e "${GRAY}   Será sobrescrito.${NC}"
  fi
  
  # Executa query
  echo -e "${WHITE}Executando query...${NC}"
  
  if [[ "$format" == "json" ]]; then
    # Executa com formato JSON
    json_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --format=json \
      --sql="$query" 2>&1)
    
    STATUS=$?
    
    if [[ $STATUS -ne 0 ]]; then
      ERROR_MSG=$(echo "$json_output" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
      if [[ -n "$ERROR_MSG" ]]; then
        FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
        echo -e "${RED}❌ Erro: ${FORMATTED_ERROR}${NC}"
      else
        echo -e "${RED}❌ Erro ao executar query.${NC}"
      fi
      save_to_history "$SQL"
      continue
    fi
    
    # Exporta para JSON
    line_count=$(export_to_json "$json_output" "$output_file")
    
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✅ Exportado com sucesso: ${output_file} (${line_count} registro(s))${NC}"
    else
      echo -e "${RED}❌ Erro ao salvar arquivo JSON.${NC}"
    fi
  else
    # Executa com formato tabular (CSV)
    csv_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="$query" 2>&1)
    
    STATUS=$?
    
    if [[ $STATUS -ne 0 ]]; then
      ERROR_MSG=$(echo "$csv_output" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
      if [[ -n "$ERROR_MSG" ]]; then
        FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
        echo -e "${RED}❌ Erro: ${FORMATTED_ERROR}${NC}"
      else
        echo -e "${RED}❌ Erro ao executar query.${NC}"
      fi
      save_to_history "$SQL"
      continue
    fi
    
    # Exporta para CSV
    # Usa arquivo temporário para capturar stderr separadamente
    temp_stderr=$(mktemp)
    line_count=$(export_to_csv "$csv_output" "$output_file" 2>"$temp_stderr")
    export_status=$?
    error_msg=$(cat "$temp_stderr" 2>/dev/null)
    rm -f "$temp_stderr"
    
    if [[ $export_status -eq 0 && -n "$line_count" && "$line_count" =~ ^[0-9]+$ ]]; then
      echo -e "${GREEN}✅ Exportado com sucesso: ${output_file} (${line_count} linha(s))${NC}"
    else
      if [[ -n "$error_msg" ]]; then
        echo -e "${RED}❌ $error_msg${NC}"
      else
        echo -e "${RED}❌ Erro ao salvar arquivo CSV.${NC}"
      fi
    fi
  fi
  
  echo -e "${NC}"
  save_to_history "$SQL"
  continue
fi
# =========================================
# ✅ COMANDO: \pagination <query> [--page-size <n>]
# =========================================
if [[ "$SQL" =~ ^\\p[[:space:]]+ ]]; then
  # Remove o comando "\p" do início
  table_cmd=$(echo "$SQL" | sed 's/^\\p[[:space:]]*//')
  
  # Extrai query SQL e opções
  query=""
  page_size=20  # Padrão
  
  # Tenta extrair query entre aspas duplas
  if [[ "$table_cmd" =~ ^\"([^\"]+)\" ]]; then
    query="${BASH_REMATCH[1]}"
    table_cmd=$(echo "$table_cmd" | sed 's/^"[^"]*"[[:space:]]*//')
  # Tenta extrair query entre aspas simples
  elif [[ "$table_cmd" =~ ^\'([^\']+)\' ]]; then
    query="${BASH_REMATCH[1]}"
    table_cmd=$(echo "$table_cmd" | sed "s/^'[^']*'[[:space:]]*//")
  else
    # Query sem aspas - extrai até encontrar --page-size
    if [[ "$table_cmd" =~ ^([^[:space:]]+[[:space:]]+.*?)[[:space:]]+--page-size ]]; then
      query=$(echo "$table_cmd" | sed 's/[[:space:]]*--page-size.*$//')
      table_cmd=$(echo "$table_cmd" | sed 's/^.*[[:space:]]*--page-size[[:space:]]*//')
    else
      # Query simples sem opções
      query="$table_cmd"
      table_cmd=""
    fi
  fi
  
  # Extrai --page-size
  if [[ "$table_cmd" =~ ^--page-size[[:space:]]+([0-9]+) ]]; then
    page_size="${BASH_REMATCH[1]}"
  elif [[ "$table_cmd" =~ ^([0-9]+) ]]; then
    page_size="${BASH_REMATCH[1]}"
  fi
  
  # Validações
  if [[ -z "$query" ]]; then
    echo -e "${RED}❌ Query SQL não informada.${NC}"
    echo -e "${WHITE}Uso: \\p \"<query>\" [--page-size <n>]${NC}"
    save_to_history "$SQL"
    continue
  fi
  
  if [[ ! "$page_size" =~ ^[0-9]+$ ]] || [[ "$page_size" -lt 1 ]] || [[ "$page_size" -gt 100 ]]; then
    echo -e "${RED}❌ Tamanho da página inválido. Deve ser entre 1 e 100.${NC}"
    save_to_history "$SQL"
    continue
  fi
  
  # Executa query
  echo -e "${WHITE}Executando query...${NC}"
  
  table_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="$query" 2>&1)
  
  STATUS=$?
  
  if [[ $STATUS -ne 0 ]]; then
    ERROR_MSG=$(echo "$table_output" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
    if [[ -n "$ERROR_MSG" ]]; then
      FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
      echo -e "${RED}❌ Erro: ${FORMATTED_ERROR}${NC}"
    else
      echo -e "${RED}❌ Erro ao executar query.${NC}"
    fi
    save_to_history "$SQL"
    continue
  fi
  
  # Verifica se há resultados
  if [[ -z "$table_output" ]]; then
    echo -e "${GRAY}Nenhum resultado encontrado.${NC}"
    save_to_history "$SQL"
    continue
  fi
  
  # Formata e exibe tabela
  format_table "$table_output" "$page_size"
  
  echo -e "${NC}"
  save_to_history "$SQL"
  continue
fi





  # clear
  if [ "$SQL" == "clear" ]; then
    clear
    show_banner
    save_to_history "$SQL"
    continue
  fi

  # SQL normal
# =========================================
# ✅ EXECUTA SQL NORMAL COM EXTRAÇÃO DE ERRO
# =========================================
if [ -n "$SQL" ]; then
  echo -e "${WHITE}"

  OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="$SQL" 2>&1)

  STATUS=$?

  if [ $STATUS -ne 0 ]; then
    # 🔹 Extrai apenas o campo "message" do JSON, se existir
    ERROR_MSG=$(echo "$OUTPUT" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')

    if [ -n "$ERROR_MSG" ]; then
      FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
      echo -e "${RED}❌ Erro: ${FORMATTED_ERROR}${NC}"
    else
      echo -e "${RED}❌ Erro: ${OUTPUT}${NC}"
    fi
  else
    # Verifica se é um comando SELECT e se há resultados
    if is_select_query "$SQL"; then
      # É um SELECT: formata como tabela sem paginação
      if [[ -n "$OUTPUT" && ! "$OUTPUT" =~ ^[[:space:]]*$ ]]; then
        format_table "$OUTPUT" 0
      else
        echo -e "${GRAY}Nenhum resultado encontrado.${NC}"
      fi
    else
      # Não é SELECT: mantém comportamento original
      echo "$OUTPUT"
    fi
  fi

  echo -e "${NC}"
  # Salva comando SQL no histórico
  save_to_history "$SQL"
fi

done
