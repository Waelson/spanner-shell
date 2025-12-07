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
    echo "  \\dt                → Lista tabelas"
    echo "  \\d <tabela>        → Describe tabela"
    echo "  \\count <tabela>    → Conta registros de uma tabela"
    echo "  \\sample <tabela>   → Mostra registros de exemplo (padrão: 10)"
    echo "  \\generate <tabela> → Gera DML de exemplo (INSERT, UPDATE, SELECT, DELETE)"
    echo "  \\ddl <tabela>      → DDL de uma tabela específica"
    echo "  \\ddl all           → DDL completo"
    echo "  \\config            → Exibe as configurações"
    echo "  \\import            → Importa o conteudo de um arquivo sql"
    echo "  \\repeat <n> <cmd>  → Executa comando N vezes"
    echo "  \\history [n]       → Exibe últimos N comandos (padrão: 20)"
    echo "  \\history clear     → Limpa o histórico"
    echo "  clear              → Limpar tela"
    echo "  exit               → Sair"
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
    echo "  Profile:  ${2}"
    echo "  Type:     ${TYPE}"
    echo "  Project:  ${PROJECT_ID}"
    echo "  Instance: ${INSTANCE_ID}"
    echo "  Database: ${DATABASE_ID}"
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


  # clear
  if [ "$SQL" == "clear" ]; then
    clear
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
