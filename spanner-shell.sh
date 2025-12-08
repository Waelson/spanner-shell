#!/bin/bash
SCRIPT_VERSION="1.0.9"

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
  echo -e "${GRAY}----------------${NC}"
  echo -e "${GRAY} \033[1mVersão\033[0;90m: v${SCRIPT_VERSION}${NC}"
  if [[ -n "$SELECTED_NAME" ]]; then
    echo -e "${GRAY} \033[1mPerfil\033[0;90m: ${SELECTED_NAME}${NC}"
  fi
  echo -e "${GRAY}----------------${NC}"
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
    mkdir -p "$output_dir" 2>/dev/null
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
      echo "$csv_header" > "$output_file"
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
      
      echo "$csv_line" >> "$output_file"
      line_count=$((line_count + 1))
    fi
  done <<< "$output_data"
  
  echo "$line_count"
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
# CONFIGURAÇÃO DO READLINE PARA HISTÓRICO ISOLADO
# =========================================
# Salva o histórico do bash atual
_OLD_HISTFILE="$HISTFILE"
_OLD_HISTSIZE="$HISTSIZE"

# Configura histórico isolado apenas para este script
export HISTFILE="$HISTORY_FILE"
export HISTSIZE=1000
export HISTFILESIZE=1000
set -o history

# Limpa o histórico do bash para começar limpo
history -c

# Carrega apenas o histórico do spanner-shell, filtrando linhas inválidas
if [[ -f "$HISTORY_FILE" ]]; then
  # Cria um arquivo temporário com apenas comandos válidos
  TEMP_HIST=$(mktemp)
  # Filtra linhas que não são comandos válidos:
  # - Remove linhas que começam com # (comentários)
  # - Remove linhas vazias ou apenas espaços
  # - Remove linhas que começam com "# =" (comentários de seção)
  while IFS= read -r line; do
    # Ignora linhas vazias, comentários e linhas que parecem ser código
    if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# && ! "$line" =~ ^[[:space:]]*$ ]]; then
      # Ignora linhas que são claramente código (contêm padrões de código)
      if [[ ! "$line" =~ ^[[:space:]]*#.*=.*$ ]]; then
        echo "$line" >> "$TEMP_HIST"
      fi
    fi
  done < "$HISTORY_FILE"
  
  # Carrega o histórico filtrado
  if [[ -s "$TEMP_HIST" ]]; then
    history -r "$TEMP_HIST"
  fi
  rm -f "$TEMP_HIST"
fi

# =========================================
# LOOP PRINCIPAL
# =========================================
while true; do
  # Configura PS1 com códigos ANSI envolvidos em \[ \] 
  export PS1="\[${GREEN}\]spanner> \[${WHITE}\]"
  
  # Lê primeira linha para detectar tipo de comando
  if ! IFS= read -r -e -p "$(printf "${GREEN}spanner> ${WHITE}")" FIRST_LINE; then
    # Restaura histórico original antes de sair
    export HISTFILE="$_OLD_HISTFILE"
    export HISTSIZE="$_OLD_HISTSIZE"
    clear
    echo "✅ Encerrando Spanner Shell..."
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
    clear
    echo "✅ Encerrando Spanner Shell..."
    exit 0
  fi

  # HELP
  if [[ "$SQL" == "\help" || "$SQL" == "\h" ]]; then
    echo -e "${WHITE}"
    echo "Comandos disponíveis:"
    echo "  \\dt                            → Lista tabelas"
    echo "  \\d <tabela>                    → Describe tabela"
    echo "  \\count <tabela>                → Conta registros de uma tabela"
    echo "  \\sample <tabela>               → Mostra registros de exemplo (padrão: 10)"
    echo "  \\tail <tabela> [n] [coluna]    → Mostra últimos N registros (padrão: 10, ordenado por PK ou coluna)"
    echo "  \\tail -f <tabela> [n] [coluna] → Monitora novos registros a cada 5 segundos"
    echo "  \\generate <tabela>             → Gera DML de exemplo (INSERT, UPDATE, SELECT, DELETE)"
    echo "  \\diff <tabela> <id1> <id2>     → Compara dois registros e mostra diferenças"
    echo "  \\ddl <tabela>                  → DDL de uma tabela específica"
    echo "  \\ddl all                       → DDL completo"
    echo "  \\pk <tabela>                   → Exibe a Primary Key da tabela"
    echo "  \\indexes <tabela>              → Lista todos os índices da tabela"
    echo "  \\config                        → Exibe as configurações"
    echo "  \\import                        → Importa o conteudo de um arquivo sql com instruções DML"
    echo "  \\import-ddl                    → Importa o conteudo de um arquivo sql com instruções DDL"
    echo "  \\export <query> --format csv|json --output <arquivo> → Exporta resultados de query para CSV ou JSON"
    echo "  \\repeat <n> <cmd>              → Executa comando N vezes"
    echo "  \\history [n]                   → Exibe últimos N comandos (padrão: 20)"
    echo "  \\history clear                 → Limpa o histórico"
    echo "  clear                          → Limpar tela"
    echo "  exit                           → Sair"
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \history
  if [[ "$SQL" =~ ^\\history($|[[:space:]]+) ]]; then
    # Verifica se é para limpar
    if [[ "$SQL" =~ ^\\history[[:space:]]+clear ]]; then
      > "$HISTORY_FILE"
      history -c
      echo -e "${GREEN}✅ Histórico limpo com sucesso!${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Extrai número de linhas (padrão: 20)
    num_lines=20
    if [[ "$SQL" =~ ^\\history[[:space:]]+([0-9]+) ]]; then
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

  # \config
  if [[ "$SQL" == "\config" ]]; then
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

  # \dt
  if [[ "$SQL" == "\dt" ]]; then
    echo -e "${WHITE}"
    gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT table_name FROM information_schema.tables WHERE table_schema = '' ORDER BY table_name;"
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \ddl all (deve ser verificado antes de \ddl <tabela>)
  if [[ "$SQL" =~ ^\\ddl[[:space:]]+all[[:space:]]*$ ]] || [[ "$SQL" == "\ddl all" ]]; then
    echo -e "${WHITE}"
    gcloud spanner databases ddl describe ${DATABASE_ID} \
      --instance=${INSTANCE_ID}
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \ddl <tabela>
  if [[ "$SQL" =~ ^\\ddl[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
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
    echo -e "${WHITE}"
    gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT column_name, spanner_type, is_nullable FROM information_schema.columns WHERE table_name = '${TABLE_NAME}' ORDER BY ordinal_position;"
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \count <tabela>
  if [[ "$SQL" =~ ^\\count[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
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

  # \sample <tabela> [n]
  if [[ "$SQL" =~ ^\\sample[[:space:]]+([a-zA-Z0-9_]+)([[:space:]]+([0-9]+))?$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    SAMPLE_SIZE="${BASH_REMATCH[3]:-10}"  # Padrão: 10 se não especificado
    
    # Valida tamanho do sample
    if [[ "$SAMPLE_SIZE" -lt 1 || "$SAMPLE_SIZE" -gt 1000 ]]; then
      echo -e "${RED}❌ Tamanho do sample deve estar entre 1 e 1000${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    echo -e "${WHITE}"
    echo "Mostrando ${SAMPLE_SIZE} registros da tabela '${TABLE_NAME}':"
    echo "----------------------------------------"
    gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT * FROM ${TABLE_NAME} LIMIT ${SAMPLE_SIZE};"
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \tail -f <tabela> [n] [coluna] (deve ser verificado antes de \tail básico)
  if [[ "$SQL" =~ ^\\tail[[:space:]]+-f[[:space:]]+([a-zA-Z0-9_]+)([[:space:]]+([0-9]+))?([[:space:]]+([a-zA-Z0-9_]+))?$ ]]; then
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
            echo -e "${WHITE}$OUTPUT${NC}"
            if [[ -n "$NEW_LAST_VALUE" && "$NEW_LAST_VALUE" != "NULL" ]]; then
              LAST_VALUE="$NEW_LAST_VALUE"
            fi
          elif [[ -n "$NEW_LAST_VALUE" && "$NEW_LAST_VALUE" != "NULL" && "$NEW_LAST_VALUE" != "$LAST_VALUE" ]]; then
            # Execuções subsequentes: mostra apenas se houver novos registros
            echo -e "${GREEN}[$(date +%H:%M:%S)] Novos registros encontrados:${NC}"
            echo -e "${WHITE}$OUTPUT${NC}"
            LAST_VALUE="$NEW_LAST_VALUE"
          fi
        fi
      else
        # Em caso de erro, tenta extrair mensagem
        ERROR_MSG=$(echo "$OUTPUT" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
        if [[ -n "$ERROR_MSG" ]]; then
          echo -e "${RED}❌ Erro: ${ERROR_MSG}${NC}"
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

  # \tail <tabela> [n] [coluna]
  if [[ "$SQL" =~ ^\\tail[[:space:]]+([a-zA-Z0-9_]+)([[:space:]]+([0-9]+))?([[:space:]]+([a-zA-Z0-9_]+))?$ ]]; then
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
    
    echo -e "${WHITE}"
    echo "Mostrando últimos ${TAIL_SIZE} registros da tabela '${TABLE_NAME}' (ordenado por ${ORDER_COLUMN}):"
    echo "----------------------------------------"
    gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT * FROM ${TABLE_NAME} ORDER BY ${ORDER_COLUMN} DESC LIMIT ${TAIL_SIZE};"
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \generate <tabela>
  if [[ "$SQL" =~ ^\\generate[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    generate_dml_examples "$TABLE_NAME"
    save_to_history "$SQL"
    continue
  fi

# =========================================
# ✅ COMANDO: \repeat <n> <comando>
# =========================================
if [[ "$SQL" =~ ^\\repeat[[:space:]]+([0-9]+)[[:space:]]+(.+)$ ]]; then
  REPEAT_COUNT="${BASH_REMATCH[1]}"
  REPEAT_CMD="${BASH_REMATCH[2]}"
  
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
        echo -e "${RED}❌ Erro: ${ERROR_MSG}${NC}"
      else
        echo -e "${RED}❌ Erro: ${OUTPUT}${NC}"
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
if [[ "$SQL" =~ ^\\import-ddl($|[[:space:]]+) ]]; then

  # Remove o comando "\import" e captura apenas o path
  FILE_PATH="$(echo "$SQL" | sed 's/^\\import-ddl[[:space:]]*//')"

  # ✅ 1. Valida se o caminho foi informado
  if [[ -z "$FILE_PATH" ]]; then
    echo -e "${RED}❌ Uso correto: \\import-ddl <caminho-do-arquivo.sql>${NC}"
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
if [[ "$SQL" =~ ^\\import($|[[:space:]]+) ]]; then

  # Remove o comando "\import" e captura apenas o path
  FILE_PATH="$(echo "$SQL" | sed 's/^\\import[[:space:]]*//')"

  # ✅ 1. Valida se o caminho foi informado
  if [[ -z "$FILE_PATH" ]]; then
    echo -e "${RED}❌ Uso correto: \\import <caminho-do-arquivo.sql>${NC}"
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
if [[ "$SQL" =~ ^\\pk[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
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
      echo -e "${RED}❌ Erro: ${ERROR_MSG}${NC}"
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
if [[ "$SQL" =~ ^\\indexes[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
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
      echo -e "${RED}❌ Erro: ${ERROR_MSG}${NC}"
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
if [[ "$SQL" =~ ^\\diff($|[[:space:]]+) ]]; then

  # Remove o comando "\diff" e captura apenas os parâmetros
  PARAMS=$(echo "$SQL" | sed 's/^\\diff[[:space:]]*//')

  # ✅ Valida quantidade de parâmetros
  PARAM_COUNT=$(echo "$PARAMS" | wc -w | tr -d ' ')

  if [[ $PARAM_COUNT -ne 3 ]]; then
    echo -e "${RED}❌ Uso correto: \\diff <tabela> <id1> <id2>${NC}"
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
if [[ "$SQL" =~ ^\\export[[:space:]]+ ]]; then
  # Remove o comando "\export" do início
  export_cmd=$(echo "$SQL" | sed 's/^\\export[[:space:]]*//')
  
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
    echo -e "${WHITE}Uso: \\export \"<query>\" --format csv|json --output <arquivo>${NC}"
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
        echo -e "${RED}❌ Erro: ${ERROR_MSG}${NC}"
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
        echo -e "${RED}❌ Erro: ${ERROR_MSG}${NC}"
      else
        echo -e "${RED}❌ Erro ao executar query.${NC}"
      fi
      save_to_history "$SQL"
      continue
    fi
    
    # Exporta para CSV
    line_count=$(export_to_csv "$csv_output" "$output_file")
    
    if [[ $? -eq 0 && -n "$line_count" ]]; then
      echo -e "${GREEN}✅ Exportado com sucesso: ${output_file} (${line_count} linha(s))${NC}"
    else
      echo -e "${RED}❌ Erro ao salvar arquivo CSV.${NC}"
    fi
  fi
  
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
      echo -e "${RED}❌ Erro: ${ERROR_MSG}${NC}"
    else
      echo -e "${RED}❌ Erro: ${OUTPUT}${NC}"
    fi
  else
    echo "$OUTPUT"
  fi

  echo -e "${NC}"
  # Salva comando SQL no histórico
  save_to_history "$SQL"
fi

done
