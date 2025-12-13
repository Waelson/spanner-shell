#!/bin/bash
SCRIPT_VERSION="1.0.13"

# =========================================
# CURSOR: BLINKING BAR
# =========================================
echo -ne "\033[5 q"

# =========================================
# CORES ANSI
# =========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
WHITE='\033[0;37m'
GRAY='\033[0;90m'
YELLOW='\033[0;33m'
NC='\033[0m'

if [[ "$1" == "--version" || "$1" == "-v" ]]; then
  echo -e "${WHITE}=======================${NC}"
  echo -e "${WHITE}Spanner Shell v${SCRIPT_VERSION}${NC}"
  echo -e "${WHITE}=======================${NC}"
  exit 0
fi

# =========================================
# PROFILE DIRECTORIES
# =========================================
PROFILE_DIR="$HOME/.spanner-shell/profiles"
mkdir -p "$PROFILE_DIR"

# =========================================
# ISOLATED HISTORY CONFIGURATION
# =========================================
HISTORY_DIR="$HOME/.spanner-shell"
HISTORY_FILE="${HISTORY_DIR}/history"
LLM_CONFIG_FILE="${HISTORY_DIR}/llm.config"
mkdir -p "$HISTORY_DIR"

# =========================================
# COMMAND: --config  (CREATE PROFILE)
# =========================================
if [[ "$1" == "--config" ]]; then
  clear
  echo -e "${WHITE}=================================${NC}"
  echo -e "${WHITE}🔧 Spanner Shell Profile Creation${NC}"
  echo -e "${WHITE}=================================${NC}"
  echo

  # Validate profile name - should not contain spaces or special characters
  while true; do
    read -p "$(echo -e "${WHITE}Profile name (ex: dev, stage, prod): ${NC}")" PROFILE_NAME
    if [[ "$PROFILE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      # Check if profile already exists
      PROFILE_FILE="${PROFILE_DIR}/${PROFILE_NAME}.env"
      if [[ -f "$PROFILE_FILE" ]]; then
        echo -e "${RED}❌ Profile '${PROFILE_NAME}' already exists. Please choose another name.${NC}"
      else
        break
      fi
    else
      echo -e "${RED}❌ Invalid profile name. Use only letters, numbers, hyphens and underscores (no spaces).${NC}"
    fi
  done
  
  # Validate TYPE - must be emulator or remote
  while true; do
    read -p "$(echo -e "${WHITE}Type (emulator | remote): ${NC}")" TYPE
    if [[ "$TYPE" == "emulator" || "$TYPE" == "remote" ]]; then
      break
    else
      echo -e "${RED}❌ Invalid type. Must be 'emulator' or 'remote'.${NC}"
    fi
  done
  
  # Validate Project ID - should not contain spaces
  while true; do
    read -p "$(echo -e "${WHITE}Project ID: ${NC}")" PROJECT_ID
    if [[ -n "$PROJECT_ID" && ! "$PROJECT_ID" =~ [[:space:]] ]]; then
      break
    else
      echo -e "${RED}❌ Invalid Project ID. Cannot contain spaces.${NC}"
    fi
  done
  
  # Validate Instance ID - should not contain spaces
  while true; do
    read -p "$(echo -e "${WHITE}Instance ID: ${NC}")" INSTANCE_ID
    if [[ -n "$INSTANCE_ID" && ! "$INSTANCE_ID" =~ [[:space:]] ]]; then
      break
    else
      echo -e "${RED}❌ Invalid Instance ID. Cannot contain spaces.${NC}"
    fi
  done
  
  # Validate Database ID - should not contain spaces
  while true; do
    read -p "$(echo -e "${WHITE}Database ID: ${NC}")" DATABASE_ID
    if [[ -n "$DATABASE_ID" && ! "$DATABASE_ID" =~ [[:space:]] ]]; then
      break
    else
      echo -e "${RED}❌ Invalid Database ID. Cannot contain spaces.${NC}"
    fi
  done

  # If emulator, ask for optional endpoint
  ENDPOINT=""
  if [[ "$TYPE" == "emulator" ]]; then
    read -p "$(echo -e "${WHITE}Endpoint (optional, default: http://localhost:9020/): ${NC}")" ENDPOINT_INPUT
    if [[ -n "$ENDPOINT_INPUT" ]]; then
      # Ensure endpoint always ends with "/"
      if [[ "$ENDPOINT_INPUT" != */ ]]; then
        ENDPOINT="${ENDPOINT_INPUT}/"
      else
        ENDPOINT="$ENDPOINT_INPUT"
      fi
    fi
  fi

  PROFILE_FILE="${PROFILE_DIR}/${PROFILE_NAME}.env"

  # Build the .env file content
  cat <<EOF > "$PROFILE_FILE"
TYPE=${TYPE}
PROJECT_ID=${PROJECT_ID}
INSTANCE_ID=${INSTANCE_ID}
DATABASE_ID=${DATABASE_ID}
EOF

  # Add ENDPOINT only if provided
  if [[ -n "$ENDPOINT" ]]; then
    echo "ENDPOINT=${ENDPOINT}" >> "$PROFILE_FILE"
  fi

  echo
  echo -e "${WHITE}✅ Profile created successfully:${NC}"
  echo -e "${WHITE}→  $PROFILE_FILE${NC}"
  echo
  echo -e "${WHITE}Use it like this:${NC}"
  echo -e "${WHITE}   spanner-shell --profile ${PROFILE_NAME}${NC}"
  echo
  exit 0
fi

# =========================================
# COMMAND: --list-profile (LIST AND SELECT PROFILE)
# =========================================
if [[ "$1" == "--list-profile" ]]; then
  clear
  echo "📋 Listing available profiles..."
  echo

  # Find all profiles
  PROFILES=()
  PROFILE_NAMES=()

  clear

  # Find all .env files in the profiles directory
  for profile_file in "$PROFILE_DIR"/*.env; do
    if [[ -f "$profile_file" ]]; then
      # Extract profile name (without .env extension)
      profile_name=$(basename "$profile_file" .env)
      PROFILES+=("$profile_file")
      PROFILE_NAMES+=("$profile_name")
    fi
  done

  # Check if there are profiles
  if [[ ${#PROFILES[@]} -eq 0 ]]; then
    echo -e "${RED}❌ No profiles found.${NC}"
    echo -e "${WHITE}➡️  Create a profile with: spanner-shell --config${NC}"
    echo
    exit 1
  fi

  # Display numbered list of profiles
  echo -e "${WHITE}======================${NC}"
  echo -e "${WHITE}📋 Available profiles:${NC}"
  echo -e "${WHITE}======================${NC}"
  echo

  # Display profiles with information
  for i in "${!PROFILE_NAMES[@]}"; do
    idx=$((i + 1))
    profile_name="${PROFILE_NAMES[$i]}"
    profile_file="${PROFILES[$i]}"

    # Read information from file without using source (to avoid polluting variables)
    # Extract TYPE and PROJECT_ID directly from file
    profile_type=$(grep "^TYPE=" "$profile_file" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "unknown")
    profile_project=$(grep "^PROJECT_ID=" "$profile_file" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "unknown")
    
    echo -e "${WHITE}   ${idx}) ${GREEN}${profile_name}${NC} (${profile_type}) - ${profile_project}"
  done

  echo
  echo -ne "${WHITE}Which profile do you want to use? (enter the number): ${NC}"
  read -r SELECTED_NUM

  # Validate input
  if [[ -z "$SELECTED_NUM" ]]; then
    echo -e "${RED}❌ No number was provided.${NC}"
    exit 1
  fi

  # Validate if it's a number
  if ! [[ "$SELECTED_NUM" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}❌ Invalid input. Please enter a number.${NC}"
    exit 1
  fi

  # Validate range
  if [[ "$SELECTED_NUM" -lt 1 || "$SELECTED_NUM" -gt ${#PROFILES[@]} ]]; then
    echo -e "${RED}❌ Invalid number. Please choose a number between 1 and ${#PROFILES[@]}.${NC}"
    exit 1
  fi

  # Get index (subtract 1 because array starts at 0)
  idx=$((SELECTED_NUM - 1))
  SELECTED_PROFILE="${PROFILES[$idx]}"
  SELECTED_NAME="${PROFILE_NAMES[$idx]}"

  # Load selected profile
  source "$SELECTED_PROFILE"

  echo
  echo -e "${GREEN}✅ Profile '${SELECTED_NAME}' loaded successfully!${NC}"
  echo
fi

# =========================================
# COMMAND: --profile <name>
# =========================================
if [[ "$1" == "--profile" && -n "$2" ]]; then
  PROFILE_FILE="${PROFILE_DIR}/${2}.env"

  if [[ ! -f "$PROFILE_FILE" ]]; then
    echo "❌ Profile '$2' not found."
    exit 1
  fi

  SELECTED_NAME="$2"
  source "$PROFILE_FILE"
fi

# =========================================
# COMMAND: --llm-setup (CONFIGURE LLM GLOBALLY)
# =========================================
if [[ "$1" == "--llm-setup" ]]; then
  clear
  echo -e "${WHITE}==================================${NC}"
  echo -e "${WHITE}🤖 Spanner Shell LLM Configuration${NC}"
  echo -e "${WHITE}==================================${NC}"
  echo
  
  # Load existing configuration if exists
  if [[ -f "$LLM_CONFIG_FILE" ]]; then
    source "$LLM_CONFIG_FILE"
  fi
  
  # Provider selection
  echo -e "${WHITE}LLM Provider:${NC}"
  echo "  1) OpenAI (default)"
  echo "  2) Exit without saving"
  echo
  read -p "$(echo -e "${WHITE}Select provider (1-2) [${LLM_PROVIDER:-1}]: ${NC}")" PROVIDER_CHOICE
  PROVIDER_CHOICE="${PROVIDER_CHOICE:-${LLM_PROVIDER:-1}}"
  
  if [[ "$PROVIDER_CHOICE" == "2" ]]; then
    echo -e "${GRAY}Cancelled.${NC}"
    exit 0
  fi
  
  LLM_PROVIDER="openai"
  
  # Model selection for OpenAI
  echo
  echo -e "${WHITE}OpenAI Models:${NC}"
  echo "  1) gpt-5.2"
  echo "  2) gpt-4o"
  echo "  3) gpt-4o-mini"
  echo "  4) gpt-4"
  echo "  5) gpt-4-turbo"
  echo "  6) gpt-3.5-turbo (default)"
  echo "  7) Custom model name"
  echo
  read -p "$(echo -e "${WHITE}Select model (1-7) [${LLM_MODEL:-6}]: ${NC}")" MODEL_CHOICE
  MODEL_CHOICE="${MODEL_CHOICE:-${LLM_MODEL:-6}}"
  
  case "$MODEL_CHOICE" in
    1)
      LLM_MODEL="gpt-5.2"
      ;;
    2)
      LLM_MODEL="gpt-4o"
      ;;
    3)
      LLM_MODEL="gpt-4o-mini"
      ;;
    4)
      LLM_MODEL="gpt-4"
      ;;
    5)
      LLM_MODEL="gpt-4-turbo"
      ;;
    6)
      LLM_MODEL="gpt-3.5-turbo"
      ;;
    7)
      read -p "$(echo -e "${WHITE}Enter custom model name: ${NC}")" CUSTOM_MODEL
      if [[ -n "$CUSTOM_MODEL" ]]; then
        LLM_MODEL="$CUSTOM_MODEL"
      else
        LLM_MODEL="gpt-3.5-turbo"
      fi
      ;;
    *)
      LLM_MODEL="${LLM_MODEL:-gpt-3.5-turbo}"
      ;;
  esac
  
  # API Token
  echo
  read -sp "$(echo -e "${WHITE}API Token (leave empty to keep current): ${NC}")" API_TOKEN_INPUT
  echo
  
  if [[ -n "$API_TOKEN_INPUT" ]]; then
    LLM_API_KEY="$API_TOKEN_INPUT"
  elif [[ -z "$LLM_API_KEY" ]]; then
    echo -e "${RED}❌ API Token is required.${NC}"
    exit 1
  fi
  
  # Save configuration
  cat <<EOF > "$LLM_CONFIG_FILE"
LLM_PROVIDER=${LLM_PROVIDER}
LLM_MODEL=${LLM_MODEL}
LLM_API_KEY=${LLM_API_KEY}
EOF
  
  # Set permissions to be readable only by owner
  chmod 600 "$LLM_CONFIG_FILE"
  
  echo
  echo -e "${GREEN}✅ LLM configuration saved successfully!${NC}"
  echo -e "${WHITE}→  $LLM_CONFIG_FILE${NC}"
  echo
  echo -e "${WHITE}Configuration:${NC}"
  echo -e "${WHITE}  Provider: ${LLM_PROVIDER}${NC}"
  echo -e "${WHITE}  Model: ${LLM_MODEL}${NC}"
  echo -e "${WHITE}  API Key: ${LLM_API_KEY:0:20}...${NC}"
  echo
  exit 0
fi

# =========================================
# VALIDATE VARIABLES
# =========================================
if [[ -z "$PROJECT_ID" || -z "$INSTANCE_ID" || -z "$DATABASE_ID" || -z "$TYPE" ]]; then
  echo
  echo -e "${RED}❌ No profile loaded.${NC}"
  echo
  echo -e "${WHITE}Use:${NC}"
  echo -e "${WHITE}  spanner-shell --config         # Create a new profile${NC}"
  echo -e "${WHITE}  spanner-shell --list-profile   # List and select a profile${NC}"
  echo -e "${WHITE}  spanner-shell --profile dev    # Use a specific profile${NC}"
  echo -e "${WHITE}  spanner-shell --llm-setup      # Configure LLM (OpenAI)${NC}"
  echo
  exit 1
fi

# =========================================
# CHECK IF GCLOUD EXISTS
# =========================================
clear

if ! command -v gcloud >/dev/null 2>&1; then
  echo -e "${RED}"
  echo "❌ gcloud is not installed."
  echo "➡️  brew install --cask google-cloud-sdk"
  echo -e "${NC}"
  echo -ne "\033[1 q"
  exit 1
fi

# =========================================
# CONFIGURE EMULATOR OR REMOTE
# =========================================
echo -e "${WHITE}"
if [[ "$TYPE" == "emulator" ]]; then
  echo "✅ Using Spanner Emulator"
  gcloud config set auth/disable_credentials true --quiet
  
  # Use endpoint from profile if available, otherwise use default
  if [[ -n "$ENDPOINT" ]]; then
    gcloud config set api_endpoint_overrides/spanner ${ENDPOINT} --quiet
  else
    gcloud config set api_endpoint_overrides/spanner http://localhost:9020/ --quiet
  fi
else
  echo "✅ Using Remote Spanner"
  gcloud config set auth/disable_credentials false
  gcloud config unset api_endpoint_overrides/spanner --quiet
  #gcloud auth application-default login
  ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

  if [[ -z "$ACTIVE_ACCOUNT" ]]; then
    echo -e "${RED}❌ No active authentication found in gcloud.${NC}"
    echo -e "${WHITE}➡️  Running: gcloud auth login${NC}"
    echo

    gcloud auth login

    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

    if [[ -z "$ACTIVE_ACCOUNT" ]]; then
      echo -e "${RED}❌ Failed to authenticate with gcloud.${NC}"
      exit 1
    fi
  fi

  echo -e "${GREEN}✅ Authenticated in gcloud as: ${ACTIVE_ACCOUNT}${NC}"


fi

gcloud config set project ${PROJECT_ID} --quiet
echo -e "${NC}"

clear

# =========================================
# FUNCTION: Display banner
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
  echo -e "${GRAY} \033[1mVersion\033[0;90m: v${SCRIPT_VERSION}${NC}"
  if [[ -n "$SELECTED_NAME" ]]; then
    echo -e "${GRAY} \033[1mProfile\033[0;90m: ${SELECTED_NAME}${NC}"
  fi
  echo -e "${GRAY}_________________${NC}"
  echo -e "${NC}"
}

# =========================================
# LLM CONFIGURATION FUNCTIONS
# =========================================

# Load LLM configuration from global file
load_llm_config() {
  if [[ -f "$LLM_CONFIG_FILE" ]]; then
    source "$LLM_CONFIG_FILE"
  fi
}

# Get current LLM provider (session override or global)
get_current_llm_provider() {
  if [[ -n "$CURRENT_LLM_PROVIDER" ]]; then
    echo "$CURRENT_LLM_PROVIDER"
  elif [[ -n "$LLM_PROVIDER" ]]; then
    echo "$LLM_PROVIDER"
  else
    echo ""
  fi
}

# Get current LLM model (session override or global)
get_current_llm_model() {
  if [[ -n "$CURRENT_LLM_MODEL" ]]; then
    echo "$CURRENT_LLM_MODEL"
  elif [[ -n "$LLM_MODEL" ]]; then
    echo "$LLM_MODEL"
  else
    echo ""
  fi
}

# Get current LLM API key (session override or global)
get_current_llm_api_key() {
  if [[ -n "$CURRENT_LLM_API_KEY" ]]; then
    echo "$CURRENT_LLM_API_KEY"
  elif [[ -n "$LLM_API_KEY" ]]; then
    echo "$LLM_API_KEY"
  else
    echo ""
  fi
}

# Load LLM configuration
load_llm_config

# =========================================
# BANNER
# =========================================
show_banner


# =========================================
# FUNCTION: Clean ANSI escape codes
# =========================================
clean_ansi() {
  local text="$1"
  # Remove all types of ANSI escape codes more aggressively
  # Remove ESC[ sequences followed by numbers/dots/commas ending in 'm'
  text=$(printf '%s' "$text" | sed 's/\x1b\[[0-9;]*m//g')
  # Remove literal sequences \033[ (escaped)
  text=$(printf '%s' "$text" | sed 's/\\033\[[0-9;]*m//g')
  # Remove ESC[ sequences without 'm' (truncated)
  text=$(printf '%s' "$text" | sed 's/\x1b\[[0-9;]*//g')
  # Remove \033[ sequences (not escaped)
  text=$(printf '%s' "$text" | sed 's/\033\[[0-9;]*m//g')
  # Remove any remaining control characters (except \n, \t, etc)
  text=$(printf '%s' "$text" | tr -d '\000-\010\013-\037\177')
  printf '%s' "$text"
}

# =========================================
# FUNCTION: Handle error message (replaces syntax errors with "Unknown command")
# =========================================
format_error_message() {
  local error_msg="$1"
  
  # Convert to lowercase for case-insensitive comparison
  local error_lower=$(echo "$error_msg" | tr '[:upper:]' '[:lower:]')
  
  # Check if it's a syntax error
  if [[ "$error_lower" =~ "syntax error" ]]; then
    echo "Unknown command"
  else
    echo "$error_msg"
  fi
}

# =========================================
# FUNCTION: Generate example value based on type
# =========================================
generate_example_value() {
  local col_type="$1"
  local is_nullable="$2"
  
  # If nullable and random, can be NULL
  if [[ "$is_nullable" == "YES" && $((RANDOM % 3)) -eq 0 ]]; then
    echo "NULL"
    return
  fi
  
  # Remove type size (ex: STRING(128) -> STRING)
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
      echo "'example'"
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
          echo "ARRAY['value1', 'value2']"
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
      echo "'value'"
      ;;
  esac
}

# =========================================
# FUNCTION: Generate example DML for a table
# =========================================
generate_dml_examples() {
  local table_name="$1"
  
  echo -e "${WHITE}"
  echo "📝 Example DML for table: ${table_name}"
  echo "=========================================="
  echo
  
  # Get column information (tabular format)
  local columns_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="SELECT column_name, spanner_type, is_nullable FROM information_schema.columns WHERE table_name = '${table_name}' ORDER BY ordinal_position;" 2>/dev/null)
  
  if [[ -z "$columns_output" || "$columns_output" =~ "not found" ]]; then
    echo -e "${RED}❌ Table '${table_name}' not found.${NC}"
    echo -e "${NC}"
    return 1
  fi
  
  # Get primary keys
  local pk_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="SELECT column_name FROM information_schema.index_columns WHERE table_name = '${table_name}' AND index_name = 'PRIMARY_KEY' ORDER BY ordinal_position;" 2>/dev/null)
  
  # Extract column names and types
  local column_names=()
  local column_types=()
  local nullable_flags=()
  local pk_columns=()
  
  # Parse columns (skip header)
  local first_line=true
  while IFS= read -r line; do
    if [[ "$first_line" == true ]]; then
      first_line=false
      continue
    fi
    if [[ -n "$line" ]]; then
      # Parse tabular line: column_name \t spanner_type \t is_nullable
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
  
  # Parse primary keys (skip header)
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
    echo -e "${RED}❌ Could not get table information.${NC}"
    echo -e "${NC}"
    return 1
  fi
  
  # Helper function to find column type
  get_column_type() {
    local col_name="$1"
    for i in "${!column_names[@]}"; do
      if [[ "${column_names[$i]}" == "$col_name" ]]; then
        echo "${column_types[$i]}"
        return
      fi
    done
  }
  
  # Generate INSERT
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
  
  # Generate SELECT
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
  
  # Generate UPDATE
  echo -e "${WHITE}-- UPDATE${NC}"
  echo -e "${WHITE}UPDATE ${table_name}"
  echo -e "${WHITE}SET "
  local set_clause=""
  local first=true
  for i in "${!column_names[@]}"; do
    # Don't update primary keys
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
    echo -e "${WHITE}WHERE <condition>;"
  fi
  echo
  
  # Generate DELETE
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
    echo -e "${WHITE}WHERE <condition>;"
  fi
  echo
  
  echo -e "${NC}"
}

# =========================================
# FUNCTION: Get primary key of a table
# =========================================
get_table_primary_key() {
  local table_name="$1"
  
  local pk_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="SELECT column_name FROM information_schema.index_columns WHERE table_name = '${table_name}' AND index_name = 'PRIMARY_KEY' ORDER BY ordinal_position LIMIT 1;" 2>/dev/null)
  
  # Parse result (skip header)
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
# FUNCTION: Get first column of a table
# =========================================
get_table_first_column() {
  local table_name="$1"
  
  local columns_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="SELECT column_name FROM information_schema.columns WHERE table_name = '${table_name}' ORDER BY ordinal_position LIMIT 1;" 2>/dev/null)
  
  # Parse result (skip header)
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
# FUNCTION: Validate if column exists in table
# =========================================
validate_column_exists() {
  local table_name="$1"
  local column_name="$2"
  
  local result=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="SELECT COUNT(*) as cnt FROM information_schema.columns WHERE table_name = '${table_name}' AND column_name = '${column_name}';" 2>/dev/null)
  
  # Parse result (look for "1" or number > 0)
  if [[ "$result" =~ [1-9] ]]; then
    return 0
  fi
  
  return 1
}

# =========================================
# FUNCTION: Get default column for ordering
# =========================================
get_default_order_column() {
  local table_name="$1"
  
  # Try to get primary key first
  local pk_col=$(get_table_primary_key "$table_name")
  if [[ -n "$pk_col" ]]; then
    echo "$pk_col"
    return 0
  fi
  
  # If no primary key, use first column
  local first_col=$(get_table_first_column "$table_name")
  if [[ -n "$first_col" ]]; then
    echo "$first_col"
    return 0
  fi
  
  return 1
}

# =========================================
# FUNCTION: Get type of a column
# =========================================
get_column_type() {
  local table_name="$1"
  local column_name="$2"
  
  local result=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="SELECT spanner_type FROM information_schema.columns WHERE table_name = '${table_name}' AND column_name = '${column_name}';" 2>/dev/null)
  
  # Parse result (skip header)
  local first_line=true
  while IFS= read -r line; do
    if [[ "$first_line" == true ]]; then
      first_line=false
      continue
    fi
    if [[ -n "$line" && "$line" != "spanner_type" ]]; then
      # Remove type size (ex: STRING(128) -> STRING)
      local base_type=$(echo "$line" | sed 's/([0-9]*)//g' | tr '[:lower:]' '[:upper:]')
      echo "$base_type"
      return 0
    fi
  done <<< "$result"
  
  return 1
}

# =========================================
# FUNCTION: Get full database DDL (all objects)
# =========================================
get_full_database_ddl() {
  gcloud spanner databases ddl describe ${DATABASE_ID} \
    --instance=${INSTANCE_ID} 2>/dev/null
}

# =========================================
# FUNCTION: Get table metadata as JSON
# =========================================
get_table_metadata() {
  local table_name="$1"
  
  # Get primary key columns with types and defaults
  local pk_query="
    SELECT 
      c.column_name,
      c.spanner_type,
      COALESCE(c.column_default, '') as column_default
    FROM information_schema.index_columns i
    JOIN information_schema.columns c
      ON i.table_name = c.table_name
     AND i.column_name = c.column_name
    WHERE i.table_name = '${table_name}'
      AND i.index_type = 'PRIMARY_KEY'
    ORDER BY i.ordinal_position;
  "
  
  local pk_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="$pk_query" 2>/dev/null)
  
  # Get all columns with defaults
  local cols_query="
    SELECT 
      column_name,
      spanner_type,
      is_nullable,
      COALESCE(column_default, '') as column_default
    FROM information_schema.columns
    WHERE table_name = '${table_name}'
    ORDER BY ordinal_position;
  "
  
  local cols_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="$cols_query" 2>/dev/null)
  
  # Get secondary indexes
  local idx_query="
    SELECT DISTINCT
      index_name,
      index_type
    FROM information_schema.index_columns
    WHERE table_name = '${table_name}'
      AND index_type != 'PRIMARY_KEY'
    ORDER BY index_name;
  "
  
  local idx_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="$idx_query" 2>/dev/null)
  
  # Build JSON manually (since we don't have jq available at this point)
  local json="{"
  json+="\"table_name\":\"${table_name}\","
  
  # Primary key
  json+="\"primary_key\":{\"columns\":["
  local first_pk=true
  local first_line=true
  while IFS= read -r line; do
    if [[ "$first_line" == true ]]; then
      first_line=false
      continue
    fi
    if [[ -n "$line" && ! "$line" =~ ^column_name ]]; then
      local col_name=$(echo "$line" | awk '{print $1}')
      local col_type=$(echo "$line" | awk '{for(i=2;i<NF;i++) printf "%s ", $i; print $(NF-1)}' | sed 's/[[:space:]]*$//')
      local col_default=$(echo "$line" | awk '{print $NF}')
      
      if [[ "$first_pk" == false ]]; then
        json+=","
      fi
      first_pk=false
      
      json+="{\"name\":\"${col_name}\",\"type\":\"${col_type}\",\"default\":\"${col_default}\"}"
    fi
  done <<< "$pk_output"
  json+="]},"
  
  # Columns
  json+="\"columns\":["
  local first_col=true
  first_line=true
  while IFS= read -r line; do
    if [[ "$first_line" == true ]]; then
      first_line=false
      continue
    fi
    if [[ -n "$line" && ! "$line" =~ ^column_name ]]; then
      local col_name=$(echo "$line" | awk '{print $1}')
      local col_type=$(echo "$line" | awk '{for(i=2;i<NF-1;i++) printf "%s ", $i; print $(NF-1)}' | sed 's/[[:space:]]*$//')
      local is_nullable=$(echo "$line" | awk '{print $(NF-1)}')
      local col_default=$(echo "$line" | awk '{print $NF}')
      
      if [[ "$first_col" == false ]]; then
        json+=","
      fi
      first_col=false
      
      # Escape quotes in default value
      col_default=$(echo "$col_default" | sed 's/"/\\"/g')
      
      json+="{\"name\":\"${col_name}\",\"type\":\"${col_type}\",\"nullable\":\"${is_nullable}\",\"default\":\"${col_default}\"}"
    fi
  done <<< "$cols_output"
  json+="],"
  
  # Indexes
  json+="\"indexes\":["
  local first_idx=true
  first_line=true
  while IFS= read -r line; do
    if [[ "$first_line" == true ]]; then
      first_line=false
      continue
    fi
    if [[ -n "$line" && ! "$line" =~ ^index_name ]]; then
      local idx_name=$(echo "$line" | awk '{print $1}')
      local idx_type=$(echo "$line" | awk '{print $2}')
      
      if [[ "$first_idx" == false ]]; then
        json+=","
      fi
      first_idx=false
      
      json+="{\"name\":\"${idx_name}\",\"type\":\"${idx_type}\"}"
    fi
  done <<< "$idx_output"
  json+="]"
  
  json+="}"
  echo "$json"
}

# =========================================
# FUNCTION: Build hotspot analysis prompt
# =========================================
build_hotspot_prompt() {
  local full_ddl="$1"
  local table_name="$2"
  local metadata="$3"
  
  cat <<EOF
You are a Google Cloud Spanner expert analyzing hotspot issues.

CONTEXT ABOUT HOTSPOTS:
Hotspots occur when many write operations concentrate on a single partition.
Patterns that cause hotspots:
1. Sequential PRIMARY KEY (DEFAULT GET_NEXT_SEQUENCE_VALUE(...)) → ALMOST CERTAIN HOTSPOT
2. PRIMARY KEY with TIMESTAMP → ALMOST CERTAIN HOTSPOT
3. INT64 PRIMARY KEY without randomization → High risk (80% of cases become hotspots)
4. STRING UUID PRIMARY KEY → Safe

COMPLETE DATABASE DDL:
${full_ddl}

TABLE TO ANALYZE: ${table_name}

SPECIFIC TABLE METADATA:
${metadata}

IMPORTANT:
- Analyze specifically the table "${table_name}"
- Consider the complete database context (shared sequences, functions, etc)
- Check if sequences used in the table are shared with other tables
- Analyze custom functions that may affect key generation
- Identify secondary indexes that may inherit hotspots from the PK
- BE CONCISE: Keep explanations short and direct (max 1-2 sentences per field)

Analyze the table "${table_name}" and return structured JSON in the format:
{
  "table_name": "${table_name}",
  "primary_key_analysis": {
    "columns": [{"name": "...", "type": "...", "default": "..."}],
    "classification": "Almost certain hotspot" | "High risk" | "Safe",
    "risk_score": 0-100,
    "reason": "brief explanation (1 sentence)",
    "impact": "performance impact in 1 sentence"
  },
  "secondary_indexes": [
    {
      "name": "...",
      "risk": "High" | "Medium" | "Low" | "None",
      "reason": "brief reason (1 sentence)",
      "avoid": "short guidance (1 sentence)"
    }
  ],
  "column_risks": [
    {
      "column": "...",
      "risk": "High" | "Medium" | "Low",
      "reason": "brief reason (max 10 words)",
      "impact": "brief impact (max 10 words)",
      "avoid": "short action (max 10 words, e.g., 'Avoid creating indexes')"
    }
  ],
  "final_score": 0-100,
  "risk_level": "HIGH" | "MEDIUM" | "LOW",
  "risk_explanation": "concise summary (2-3 sentences max)",
  "recommendations": [
    "specific actionable recommendation with code examples when applicable"
  ]
}

IMPORTANT: Return ONLY valid JSON, without any additional text before or after. Do not include explanations, comments, or markdown. Only the pure JSON object.
EOF
}

# =========================================
# FUNCTION: Call OpenAI API
# =========================================
call_openai_api() {
  local prompt="$1"
  local model="${2:-gpt-3.5-turbo}"
  local api_key="$3"
  
  # Check if curl is installed
  if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is not installed" >&2
    return 1
  fi
  
  # Check if jq is installed
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is not installed" >&2
    return 1
  fi
  
  # Build JSON payload using jq for proper escaping
  # Note: response_format is not supported by all models, so we rely on prompt instructions
  local json_payload=$(jq -n \
    --arg model "$model" \
    --arg prompt "$prompt" \
    '{
      model: $model,
      messages: [{role: "user", content: $prompt}],
      temperature: 0.3
    }' 2>/dev/null)
  
  if [[ -z "$json_payload" ]]; then
    echo "ERROR: Failed to build JSON payload" >&2
    return 1
  fi
  
  # Make API call with timeout
  local response=$(curl -s -w "\n%{http_code}" \
    -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d "$json_payload" \
    --max-time 60 2>&1)
  
  local http_code=$(echo "$response" | tail -n 1)
  local body=$(echo "$response" | sed '$d')
  
  # Check HTTP status
  if [[ "$http_code" != "200" ]]; then
    case "$http_code" in
      401)
        echo "ERROR: Invalid API key" >&2
        ;;
      429)
        echo "ERROR: Rate limit exceeded" >&2
        ;;
      500)
        echo "ERROR: OpenAI server error" >&2
        ;;
      *)
        echo "ERROR: HTTP $http_code - $body" >&2
        ;;
    esac
    return 1
  fi
  
  # Extract content from response
  local content=$(echo "$body" | jq -r '.choices[0].message.content' 2>/dev/null)
  
  if [[ -z "$content" || "$content" == "null" ]]; then
    echo "ERROR: Invalid response from API" >&2
    return 1
  fi
  
  # Try to extract JSON if the response contains text before/after JSON
  # Remove markdown code blocks if present
  content=$(echo "$content" | sed 's/```json//g' | sed 's/```//g' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  
  # Try to extract JSON object if wrapped in text
  if ! echo "$content" | jq . >/dev/null 2>&1; then
    # Try to find JSON object in the response
    local json_match=$(echo "$content" | grep -o '{.*}' | head -n 1)
    if [[ -n "$json_match" ]] && echo "$json_match" | jq . >/dev/null 2>&1; then
      content="$json_match"
    else
      echo "ERROR: Could not extract valid JSON from response" >&2
      return 1
    fi
  fi
  
  echo "$content"
  return 0
}

# =========================================
# FUNCTION: Format hotspot report
# =========================================
format_hotspot_report() {
  local json_response="$1"
  
  # Validate JSON
  if ! echo "$json_response" | jq . >/dev/null 2>&1; then
    echo -e "${RED}❌ Invalid LLM response${NC}"
    return 1
  fi
  
  # Extract fields
  local table_name=$(echo "$json_response" | jq -r '.table_name // empty' 2>/dev/null)
  local final_score=$(echo "$json_response" | jq -r '.final_score // 0' 2>/dev/null)
  local risk_level=$(echo "$json_response" | jq -r '.risk_level // "UNKNOWN"' 2>/dev/null)
  
  # Display header
  echo -e "${WHITE}════════════════════════════════════════════${NC}"
  echo -e "${WHITE}🔥 HOTSPOT ANALYSIS — TABLE: ${table_name}${NC}"
  echo -e "${WHITE}════════════════════════════════════════════${NC}"
  echo
  echo -e "${GRAY}What is a Hotspot?${NC}"
  echo -e "${GRAY}A hotspot occurs when many write operations concentrate${NC}"
  echo -e "${GRAY}on a single partition, causing performance degradation.${NC}"
  echo -e "${GRAY}Sequential keys (timestamps, auto-increment IDs) are${NC}"
  echo -e "${GRAY}the primary cause. This analysis identifies patterns${NC}"
  echo -e "${GRAY}that may lead to hotspots in your table.${NC}"
  echo
  
  # Primary Key Analysis
  echo
  echo -e "${WHITE}------------${NC}"
  echo -e "${WHITE}Primary Key:${NC}"
  echo -e "${WHITE}------------${NC}"
  local pk_columns=$(echo "$json_response" | jq -r '.primary_key_analysis.columns[]? | "\(.name) (\(.type))"' 2>/dev/null | head -5)
  while IFS= read -r pk_line; do
    if [[ -n "$pk_line" ]]; then
      echo -e "${WHITE}- ${pk_line}${NC}"
    fi
  done <<< "$pk_columns"
  
  local pk_default=$(echo "$json_response" | jq -r '.primary_key_analysis.columns[0].default // ""' 2>/dev/null)
  if [[ -n "$pk_default" && "$pk_default" != "null" && "$pk_default" != "" ]]; then
    echo -e "${WHITE}- Default: ${pk_default}${NC}"
  fi
  
  local pk_classification=$(echo "$json_response" | jq -r '.primary_key_analysis.classification // ""' 2>/dev/null)
  local pk_reason=$(echo "$json_response" | jq -r '.primary_key_analysis.reason // ""' 2>/dev/null)
  local pk_impact=$(echo "$json_response" | jq -r '.primary_key_analysis.impact // ""' 2>/dev/null)
  
  if [[ -n "$pk_classification" ]]; then
    if [[ "$pk_classification" == *"Almost certain hotspot"* ]] || [[ "$pk_classification" == *"ALMOST CERTAIN"* ]]; then
      echo -e "${RED}❌ Classification: ${pk_classification}${NC}"
    elif [[ "$pk_classification" == *"High risk"* ]] || [[ "$pk_classification" == *"HIGH"* ]]; then
      echo -e "${YELLOW}⚠️  Classification: ${pk_classification}${NC}"
    else
      echo -e "${GREEN}✅ Classification: ${pk_classification}${NC}"
    fi
    
    if [[ -n "$pk_reason" && "$pk_reason" != "null" ]]; then
      echo -e "${GRAY}🧠  Reason: ${pk_reason}${NC}"
    fi
    
    if [[ -n "$pk_impact" && "$pk_impact" != "null" ]]; then
      echo -e "${GRAY}💥  Impact: ${pk_impact}${NC}"
    fi
  fi
  
  echo
  
  # Secondary Indexes
  local idx_count=$(echo "$json_response" | jq '.secondary_indexes | length' 2>/dev/null)
  if [[ "$idx_count" -gt 0 ]]; then
    echo
    echo -e "${WHITE}------------------${NC}"
    echo -e "${WHITE}Secondary Indexes:${NC}"
    echo -e "${WHITE}------------------${NC}"
    
    echo "$json_response" | jq -c '.secondary_indexes[]?' 2>/dev/null | while IFS= read -r idx_json; do
      local idx_name=$(echo "$idx_json" | jq -r '.name // ""')
      local idx_risk=$(echo "$idx_json" | jq -r '.risk // "None"')
      local idx_reason=$(echo "$idx_json" | jq -r '.reason // ""')
      local idx_avoid=$(echo "$idx_json" | jq -r '.avoid // ""')
      
      if [[ -n "$idx_name" ]]; then
        # Determine color based on risk
        local color="${WHITE}"
        if [[ "$idx_risk" == *"High"* ]] || [[ "$idx_risk" == *"HIGH"* ]]; then
          color="${RED}"
        elif [[ "$idx_risk" == *"Medium"* ]] || [[ "$idx_risk" == *"MEDIUM"* ]]; then
          color="${YELLOW}"
        fi
        
        echo -e "${color}- ${idx_name} → ${idx_risk}${NC}"
        
        if [[ -n "$idx_reason" && "$idx_reason" != "null" ]]; then
          echo -e "${GRAY}🧠  Reason: ${idx_reason}${NC}"
        fi
        
        if [[ -n "$idx_avoid" && "$idx_avoid" != "null" ]]; then
          echo -e "${GRAY}⚠️  Avoid: ${idx_avoid}${NC}"
        fi
      fi
    done
    echo
  fi
  
  # Column Risks
  local col_risk_count=$(echo "$json_response" | jq '.column_risks | length' 2>/dev/null)
  if [[ "$col_risk_count" -gt 0 ]]; then
    echo
    echo -e "${WHITE}-------------${NC}"
    echo -e "${WHITE}Column Risks:${NC}"
    echo -e "${WHITE}-------------${NC}"
    
    echo "$json_response" | jq -c '.column_risks[]?' 2>/dev/null | while IFS= read -r col_json; do
      local col_name=$(echo "$col_json" | jq -r '.column // ""')
      local col_risk=$(echo "$col_json" | jq -r '.risk // ""')
      local col_reason=$(echo "$col_json" | jq -r '.reason // ""')
      local col_impact=$(echo "$col_json" | jq -r '.impact // ""')
      local col_avoid=$(echo "$col_json" | jq -r '.avoid // ""')
      
      if [[ -n "$col_name" ]]; then
        # Determine color based on risk
        local color="${WHITE}"
        if [[ "$col_risk" == *"High"* ]] || [[ "$col_risk" == *"HIGH"* ]]; then
          color="${RED}"
        elif [[ "$col_risk" == *"Medium"* ]] || [[ "$col_risk" == *"MEDIUM"* ]]; then
          color="${YELLOW}"
        fi
        
        echo -e "${color}- ${col_name} → ${col_risk}${NC}"
        
        if [[ -n "$col_reason" && "$col_reason" != "null" ]]; then
          echo -e "${GRAY}🧠  Reason: ${col_reason}${NC}"
        fi
        
        if [[ -n "$col_impact" && "$col_impact" != "null" ]]; then
          echo -e "${GRAY}💥  Impact: ${col_impact}${NC}"
        fi
        
        if [[ -n "$col_avoid" && "$col_avoid" != "null" ]]; then
          echo -e "${GRAY}⚠️  Avoid: ${col_avoid}${NC}"
        fi
        
        echo
      fi
    done
    echo
  fi
  
  # Final Score and Risk Level
  echo
  echo -e "${WHITE}-----------------------${NC}"
  echo -e "${WHITE}Score Final: ${final_score} / 100${NC}"
  echo -e "${WHITE}-----------------------${NC}"
  
  case "$risk_level" in
    "ALTO"|"HIGH")
      echo -e "${RED}Risk Level: 🔴 HIGH${NC}"
      ;;
    "MÉDIO"|"MEDIUM")
      echo -e "${YELLOW}Risk Level: 🟡 MEDIUM${NC}"
      ;;
    "BAIXO"|"LOW")
      echo -e "${GREEN}Risk Level: 🟢 LOW${NC}"
      ;;
    *)
      echo -e "${GRAY}Risk Level: ${risk_level}${NC}"
      ;;
  esac
  
  # Risk explanation
  local risk_explanation=$(echo "$json_response" | jq -r '.risk_explanation // ""' 2>/dev/null)
  if [[ -n "$risk_explanation" && "$risk_explanation" != "null" ]]; then
    echo
    echo -e "${GRAY}${risk_explanation}${NC}"
  fi
  
  echo
  
  # Recommendations
  local rec_count=$(echo "$json_response" | jq '.recommendations | length' 2>/dev/null)
  if [[ "$rec_count" -gt 0 ]]; then
    echo
    echo -e "${WHITE}-------------------${NC}"
    echo -e "${WHITE}✅ Recommendations:${NC}"
    echo -e "${WHITE}-------------------${NC}"
    echo "$json_response" | jq -r '.recommendations[]?' 2>/dev/null | while IFS= read -r rec; do
      if [[ -n "$rec" ]]; then
        echo -e "${WHITE}- ${rec}${NC}"
      fi
    done
  fi
  
  echo
}

# =========================================
# FUNCTION: Save command to history
# =========================================
save_to_history() {
  local cmd="$1"
  # Ignore empty commands or only spaces
  if [[ -z "${cmd// }" ]]; then
    return
  fi
  
  # Remove ANSI escape codes before saving
  local clean_cmd=$(clean_ansi "$cmd")
  
  # Ignore commands that are comments or code lines
  if [[ "$clean_cmd" =~ ^[[:space:]]*# ]]; then
    return
  fi
  
  # Ignore commands that are only spaces or special characters
  if [[ ! "$clean_cmd" =~ [a-zA-Z0-9] ]]; then
    return
  fi
  
  # Ignore commands that are too long (maximum 500 characters)
  if [[ ${#clean_cmd} -gt 500 ]]; then
    return
  fi
  
  # Ignore commands that seem to be script code (contain bash patterns)
  if [[ "$clean_cmd" =~ (BASH_REMATCH|HISTFILE|HISTSIZE|HISTFILESIZE|clean_ansi|format_table|IFS=|read -r -e|printf|sed -E|gcloud spanner|export |local |if \[\[|elif \[\[|else|fi|while|for|do|done|function |return |echo -e) ]]; then
    return
  fi
  
  # Add to bash history (which is isolated)
  history -s "$clean_cmd"
  
  # Save to file immediately
  history -w "$HISTORY_FILE"
}

# =========================================
# FUNCTION: Export results to CSV
# =========================================
export_to_csv() {
  local output_data="$1"
  local output_file="$2"
  
  # Create directory if it doesn't exist
  local output_dir=$(dirname "$output_file")
  if [[ -n "$output_dir" && "$output_dir" != "." ]]; then
    if ! mkdir -p "$output_dir" 2>/dev/null; then
      echo "Error creating directory: $output_dir" >&2
      return 1
    fi
  fi
  
  # Process tabular data
  local first_line=true
  local line_count=0
  
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      continue
    fi
    
    if [[ "$first_line" == true ]]; then
      # First line = header - convert tabs to commas
      first_line=false
      local csv_header=$(echo "$line" | tr '\t' ',')
      if ! echo "$csv_header" > "$output_file" 2>/dev/null; then
        echo "Error writing header to file: $output_file" >&2
        return 2
      fi
      line_count=1
    else
      # Data lines - process each field
      local csv_line=""
      IFS=$'\t' read -ra FIELDS <<< "$line"
      local first_field=true
      
      for field in "${FIELDS[@]}"; do
        if [[ "$first_field" == false ]]; then
          csv_line+=","
        fi
        first_field=false
        
        # If field contains comma, quotes or newline, wrap in quotes
        if [[ "$field" =~ [,,\"$'\n'$'\r'] ]]; then
          # Escape double quotes (duplicate them)
          field=$(echo "$field" | sed 's/"/""/g')
          csv_line+="\"$field\""
        else
          csv_line+="$field"
        fi
      done
      
      if ! echo "$csv_line" >> "$output_file" 2>/dev/null; then
        echo "Error writing line to file: $output_file" >&2
        return 3
      fi
      line_count=$((line_count + 1))
    fi
  done <<< "$output_data"
  
  # Return line_count via stdout only if everything was successful
  echo "$line_count"
  return 0
}

# =========================================
# FUNCTION: Export results to JSON
# =========================================
export_to_json() {
  local json_data="$1"
  local output_file="$2"
  
  # Create directory if it doesn't exist
  local output_dir=$(dirname "$output_file")
  if [[ -n "$output_dir" && "$output_dir" != "." ]]; then
    mkdir -p "$output_dir" 2>/dev/null
  fi
  
  # Check if jq is available
  if command -v jq >/dev/null 2>&1; then
    # Use jq to format JSON nicely
    echo "$json_data" | jq '.' > "$output_file" 2>/dev/null
    if [[ $? -eq 0 ]]; then
      # Count lines (number of objects in array)
      local line_count=$(echo "$json_data" | jq 'if type == "array" then length elif type == "object" and has("rows") then (.rows | length) else 0 end' 2>/dev/null || echo "0")
      echo "$line_count"
      return 0
    fi
  fi
  
  # Fallback: save JSON without formatting (should already be valid from gcloud)
  echo "$json_data" > "$output_file"
  if [[ $? -eq 0 ]]; then
    # Try to count objects manually (approximate)
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
# FUNCTION: Detect column type (numeric or text)
# =========================================
detect_column_type() {
  local sample_value="$1"
  
  # Remove spaces
  sample_value=$(echo "$sample_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # If empty or NULL, assume text
  if [[ -z "$sample_value" || "$sample_value" == "NULL" ]]; then
    echo "text"
    return
  fi
  
  # Check if it's a number (integer or decimal)
  if [[ "$sample_value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    echo "numeric"
  else
    echo "text"
  fi
}

# =========================================
# FUNCTION: Detect if a SQL command is a SELECT
# =========================================
is_select_query() {
  local sql="$1"
  
  # Remove leading and trailing spaces
  sql=$(echo "$sql" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Remove single-line SQL comments (-- comment)
  sql=$(echo "$sql" | sed 's/--.*$//')
  
  # Remove simple block SQL comments (/* comment */)
  # Note: This is a simple implementation that doesn't handle complex multi-line comments
  sql=$(echo "$sql" | sed 's/\/\*[^*]*\*\///g')
  
  # Remove spaces again after removing comments
  sql=$(echo "$sql" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Check if it starts with SELECT (case-insensitive)
  if [[ "$sql" =~ ^[Ss][Ee][Ll][Ee][Cc][Tt][[:space:]] ]]; then
    return 0
  fi
  
  return 1
}

# =========================================
# FUNCTION: Calculate column widths
# =========================================
calculate_column_widths() {
  local data="$1"
  local max_width="${2:-50}"  # Default maximum width per column
  
  # Array to store widths
  declare -a widths
  
  # Process first line (header)
  local first_line=true
  local num_columns=0
  
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      continue
    fi
    
    IFS=$'\t' read -ra FIELDS <<< "$line"
    
    if [[ "$first_line" == true ]]; then
      # First line = header
      num_columns=${#FIELDS[@]}
      for i in "${!FIELDS[@]}"; do
        widths[$i]=${#FIELDS[$i]}
      done
      first_line=false
    else
      # Data lines - update width if necessary
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
  
  # Apply maximum limit and print widths
  for i in $(seq 0 $((num_columns - 1))); do
    if [[ ${widths[$i]} -gt $max_width ]]; then
      widths[$i]=$max_width
    fi
    echo "${widths[$i]}"
  done
}

# =========================================
# FUNCTION: Format and display table
# =========================================
format_table() {
  local output_data="$1"
  local page_size="${2:-20}"
  local use_alternating_colors="${3:-true}"  # Default: true (alternating color active)
  
  # Check if there is data
  if [[ -z "$output_data" ]]; then
    echo -e "${GRAY}No results found.${NC}"
    return 1
  fi
  
  # Count number of columns first
  local first_line=$(echo "$output_data" | head -n 1)
  IFS=$'\t' read -ra HEADER_FIELDS <<< "$first_line"
  local num_columns=${#HEADER_FIELDS[@]}
  
  # Calculate column widths considering the number of columns
  local terminal_width=$(tput cols 2>/dev/null || echo 80)
  
  # Calculate space needed for borders and separators
  # Structure: │ space content space │ space content space │
  # For N columns: │ (1) + N * (space(1) + content + space(1) + │(1)) = 1 + N * 3 + sum(widths)
  # Fixed overhead per column: 3 characters (space before + space after + │ separator)
  # Total fixed overhead: 1 (initial │) + N * 3
  # Note: Last column also has │ at the end, so there are N │ separators
  local border_overhead=$((1 + num_columns * 3))
  
  # Available space for column content
  local available_width=$((terminal_width - border_overhead))
  
  # Calculate widths without limit first to see real size needed
  local widths_str=$(calculate_column_widths "$output_data" "9999")
  # Use compatible method instead of readarray
  widths=()
  local total_min_width=0
  while IFS= read -r width_val; do
    if [[ -n "$width_val" ]]; then
      widths+=("$width_val")
      total_min_width=$((total_min_width + width_val))
    fi
  done <<< "$widths_str"
  
  # Calculate total space needed (widths + overhead)
  local total_needed_width=$((total_min_width + border_overhead))
  
  # If needed space is less than available, expand columns proportionally
  if [[ $total_needed_width -lt $terminal_width && $total_min_width -gt 0 ]]; then
    # Use 95% of terminal to distribute among columns
    local target_total_width=$((terminal_width * 95 / 100))
    local target_content_width=$((target_total_width - border_overhead))
    
    if [[ $target_content_width -gt $total_min_width ]]; then
      # Expand proportionally
      local scale_factor=$((target_content_width * 100 / total_min_width))
      
      for i in "${!widths[@]}"; do
        local scaled_width=$((widths[$i] * scale_factor / 100))
        widths[$i]=$scaled_width
      done
    fi
  fi
  
  # Apply maximum limit only if necessary (to avoid extremely wide columns)
  # More generous limit based on number of columns
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
    # Ensure minimum of 10 characters
    if [[ ${widths[$i]} -lt 10 ]]; then
      widths[$i]=10
    fi
  done
  
  # Process data line by line
  local all_lines=()
  local line_num=0
  
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      all_lines+=("$line")
      line_num=$((line_num + 1))
    fi
  done <<< "$output_data"
  
  local total_lines=${#all_lines[@]}
  local data_lines=$((total_lines - 1))  # Exclude header
  
  # Determine if should use pagination or display everything at once
  local no_pagination=false
  if [[ $page_size -eq 0 ]] || [[ $page_size -gt 99999 ]]; then
    no_pagination=true
    page_size=$data_lines  # Set page_size as total lines to display everything
  fi
  
  local total_pages=1
  if [[ $data_lines -gt 0 && "$no_pagination" == false ]]; then
    total_pages=$(( (data_lines + page_size - 1) / page_size ))
  fi
  
  # Helper function to draw border line
  draw_border() {
    local char="$1"  # ┌, ├, or └
    local mid_char="$2"  # ┬, ┼, or ┴
    local end_char="$3"  # ┐, ┤, or ┘
    
    echo -ne "${WHITE}$char"
    for i in $(seq 0 $((num_columns - 1))); do
      # Each column has: 1 space before + content + 1 space after = widths[$i] + 2
      for j in $(seq 1 $((${widths[$i]} + 2))); do
        echo -ne "─"
      done
      if [[ $i -lt $((num_columns - 1)) ]]; then
        echo -ne "$mid_char"
      fi
    done
    echo -e "${NC}$end_char"
  }
  
  # Helper function to format cell
  format_cell() {
    local value="$1"
    local width="$2"
    local align="$3"  # "left" or "right"
    
    # Truncate if too long (ensure width is at least 3)
    if [[ ${#value} -gt $width && $width -ge 3 ]]; then
      value="${value:0:$((width - 3))}..."
    elif [[ ${#value} -gt $width && $width -lt 3 ]]; then
      # If width is too small, truncate to maximum possible size
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
  
  # Pagination loop (or single display if no_pagination=true)
  local current_page=1
  local start_data_line=1  # Start at line 1 (skip header at line 0)
  
  while [[ $current_page -le $total_pages ]]; do
    # Draw top border
    draw_border "┌" "┬" "┐"
    
    # Header with highlighted color
    echo -ne "${WHITE}│${NC}"  # Left border first (white)
    echo -ne "\033[44m\033[97m"  # Apply color after border
    for i in $(seq 0 $((num_columns - 1))); do
      local header_val="${HEADER_FIELDS[$i]}"
      echo -ne " "
      format_cell "$header_val" "${widths[$i]}" "left"
      if [[ $i -eq $((num_columns - 1)) ]]; then
        # Last column: reset color before final │
        echo -ne " \033[0m${WHITE}│${NC}"
      else
        echo -ne " ${WHITE}│${NC}"
      fi
    done
    echo  # New line
    
    # Header separator
    draw_border "├" "┼" "┤"
    
    # Data lines
    local end_data_line=$((start_data_line + page_size - 1))
    if [[ $end_data_line -ge $total_lines ]]; then
      end_data_line=$((total_lines - 1))
    fi
    
    local displayed_count=0
    for line_idx in $(seq $start_data_line $end_data_line); do
      if [[ $line_idx -lt $total_lines ]]; then
        local data_line="${all_lines[$line_idx]}"
        IFS=$'\t' read -ra FIELDS <<< "$data_line"
        
        # Print left border first (white)
        echo -ne "${WHITE}│${NC}"
        
        # Apply alternating color if enabled
        local has_bg_color=false
        if [[ "$use_alternating_colors" == "true" && $((displayed_count % 2)) -eq 1 ]]; then
          has_bg_color=true
        fi
        
        for i in $(seq 0 $((num_columns - 1))); do
          # Apply background color and white text at start of each cell
          if [[ "$has_bg_color" == true ]]; then
            echo -ne "\033[48;5;240m\033[37m"  # Gray background + white text
          else
            echo -ne "\033[37m"  # White text only
          fi
          
          local field_val="${FIELDS[$i]:-}"
          local col_type=$(detect_column_type "$field_val")
          local align="left"
          if [[ "$col_type" == "numeric" ]]; then
            align="right"
          fi
          
          echo -ne " "
          format_cell "$field_val" "${widths[$i]}" "$align"
          
          # Reset colors before border
          echo -ne " \033[0m${WHITE}│${NC}"
        done
        echo  # New line
        displayed_count=$((displayed_count + 1))
      fi
    done
    
    # Bottom border
    draw_border "└" "┴" "┘"
    
    # Pagination information (only if not in no-pagination mode and there are multiple pages)
    if [[ "$no_pagination" == false && $total_pages -gt 1 ]]; then
      echo -e "${GRAY}[Page ${current_page}/${total_pages}] - Press Enter for next page, 'q' to exit${NC}"
      
      # Wait for input
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
# READLINE CONFIGURATION FOR ISOLATED HISTORY
# History is cleared at each initialization, keeping only the current session
# =========================================
# Save current bash history
_OLD_HISTFILE="$HISTFILE"
_OLD_HISTSIZE="$HISTSIZE"

# Configure isolated history only for this script
export HISTFILE="$HISTORY_FILE"
export HISTSIZE=1000
export HISTFILESIZE=1000
export HISTCONTROL=ignoredups:ignorespace:erasedups
# Disable history during script execution to avoid capturing script lines
set +o history

# Clear history file to start clean session
# Each session keeps only its own history
if [[ -f "$HISTORY_FILE" ]]; then
  > "$HISTORY_FILE"
fi

# =========================================
# MAIN LOOP
# =========================================
# Enable history only when main loop starts
set -o history
history -c

while true; do
  # Configure PS1 with ANSI codes wrapped in \[ \] 
  export PS1="\[${GREEN}\]spanner> \[${WHITE}\]"
  
  # Read first line to detect command type
  if ! IFS= read -r -e -p "$(printf "${GREEN}spanner> ${WHITE}")" FIRST_LINE; then
    # Disable history before exiting
    set +o history
    # Restore original history before exiting
    export HISTFILE="$_OLD_HISTFILE"
    export HISTSIZE="$_OLD_HISTSIZE"
    clear
    echo " Shutting down Spanner Shell..."
    exit 0
  fi
  
  echo -ne "${NC}"
  
  # Remove spaces and ANSI codes from first line
  FIRST_LINE=$(printf '%s' "$FIRST_LINE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  FIRST_LINE=$(clean_ansi "$FIRST_LINE")
  FIRST_LINE=$(clean_ansi "$FIRST_LINE")
  
  # Ignore empty lines
  if [[ -z "${FIRST_LINE// }" ]]; then
    continue
  fi
  
  # Detect if it's a special command (starts with \) or control command
  if [[ "$FIRST_LINE" =~ ^\\ ]] || \
     [[ "$FIRST_LINE" == "exit" ]] || \
     [[ "$FIRST_LINE" == "clear" ]] || \
     [[ "$FIRST_LINE" == "\help" ]] || \
     [[ "$FIRST_LINE" == "\h" ]]; then
    # Special command: single line
    SQL="$FIRST_LINE"
  else
    # SQL command: allows multi-line
    # Remove trailing spaces and check if it ends with ;
    FIRST_LINE_TRIMMED=$(echo "$FIRST_LINE" | sed 's/[[:space:]]*$//')
    if [[ "$FIRST_LINE_TRIMMED" == *";" ]]; then
      # Already ends with ; - execute immediately
      SQL=$(echo "$FIRST_LINE_TRIMMED" | sed 's/[[:space:]]*;[[:space:]]*$//')
    else
      # Continue reading until finding ;
      SQL_BUFFER="$FIRST_LINE"
      while true; do
        if ! IFS= read -r -e -p "$(printf "${GRAY}    ... ${WHITE}")" NEXT_LINE; then
          # If EOF (Ctrl+D), cancel
          SQL=""
          break
        fi
        echo -ne "${NC}"
        
        # Remove spaces and ANSI codes
        NEXT_LINE=$(printf '%s' "$NEXT_LINE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        NEXT_LINE=$(clean_ansi "$NEXT_LINE")
        NEXT_LINE=$(clean_ansi "$NEXT_LINE")
        
        # If empty line, add space and continue
        if [[ -z "$NEXT_LINE" ]]; then
          SQL_BUFFER+=" "
          continue
        fi
        
        # Add line to buffer
        SQL_BUFFER+=" $NEXT_LINE"
        
        # Remove trailing spaces and check if it ends with ;
        SQL_BUFFER_TRIMMED=$(echo "$SQL_BUFFER" | sed 's/[[:space:]]*$//')
        if [[ "$SQL_BUFFER_TRIMMED" == *";" ]]; then
          # Remove final ;
          SQL=$(echo "$SQL_BUFFER_TRIMMED" | sed 's/[[:space:]]*;[[:space:]]*$//')
          break
        fi
      done
      
      # If SQL empty (cancelled), continue loop
      if [[ -z "$SQL" ]]; then
        continue
      fi
    fi
  fi
  
  # Remove leading and trailing whitespace from final SQL
  SQL=$(printf '%s' "$SQL" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Ignore empty commands after cleanup
  if [[ -z "${SQL// }" ]]; then
    continue
  fi

  if [ "$SQL" == "exit" ]; then
    # Save history before exiting
    history -w "$HISTORY_FILE"
    # Disable history before exiting
    set +o history
    clear
    echo "✅ Shutting down Spanner Shell..."
    exit 0
  fi

  # HELP
  if [[ "$SQL" == "\help" || "$SQL" == "\h" ]]; then
    echo -e "${WHITE}"
    echo "Available commands:"
    echo "  \\t                             → List tables"
    echo "  \\d <table>                     → Describe table"
    echo "  \\n <table>                     → Count records in a table"
    echo "  \\s <table>                     → Show sample records (default: 10)"
    echo "  \\l <table> [n] [column]        → Show last N records (default: 10, ordered by PK or column)"
    echo "  \\f <table> [n] [column]        → Monitor new records every 5 seconds"
    echo "  \\g <table>                     → Generate example DML (INSERT, UPDATE, SELECT, DELETE)"
    echo "  \\df <table> <id1> <id2>        → Compare two records and show differences"
    echo "  \\dd <table>                    → DDL of a specific table"
    echo "  \\da                            → Complete DDL"
    echo "  \\k <table>                     → Display the Primary Key of the table"
    echo "  \\i <table>                     → List all indexes of the table"
    echo "  \\c                             → Display configuration"
    echo "  \\llm [show|select]             → Show or select LLM configuration"
    echo "  \\hotspot-ai <table>            → AI-powered hotspot analysis for a table"
    echo "  \\im                            → Import content from a sql file with DML instructions"
    echo "  \\id                            → Import content from a sql file with DDL instructions"
    echo "  \\e <query> --format csv|json --output <file> → Export query results to CSV or JSON"
    echo "  \\p <query> [--page-size <n>]   → Display results in formatted table with pagination"
    echo "  \\r <n> <cmd>                   → Execute command N times"
    echo "  \\hi [n]                        → Display last N commands (default: 20)"
    echo "  \\hc                            → Clear history"
    echo "  clear                          → Clear screen"
    echo "  exit                           → Exit"
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \hc (must be checked before \hi)
  if [[ "$SQL" == "\\hc" ]]; then
    > "$HISTORY_FILE"
    history -c
    echo -e "${GREEN}✅ History cleared successfully!${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \hi
  if [[ "$SQL" =~ ^\\hi($|[[:space:]]+) ]]; then
    # Check if it's to clear
    if [[ "$SQL" =~ ^\\hi[[:space:]]+clear ]]; then
      > "$HISTORY_FILE"
      history -c
      echo -e "${GREEN}✅ History cleared successfully!${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Extract number of lines (default: 20)
    num_lines=20
    if [[ "$SQL" =~ ^\\hi[[:space:]]+([0-9]+) ]]; then
      num_lines="${BASH_REMATCH[1]}"
    fi
    
    echo -e "${WHITE}"
    echo "Last ${num_lines} commands:"
    echo "----------------------------------------"
    # Show last N commands from history
    history | tail -n $((num_lines + 1)) | head -n $num_lines | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//'
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \c
  if [[ "$SQL" == "\c" ]]; then
    echo -e "${WHITE}"
    echo "Configuration:"
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

  # \llm commands
  if [[ "$SQL" =~ ^\\llm($|[[:space:]]) ]]; then
    LLM_CMD=$(echo "$SQL" | sed 's/^\\llm[[:space:]]*//' | awk '{print $1}')
    
    case "$LLM_CMD" in
      "show"|"")
        CURRENT_PROVIDER=$(get_current_llm_provider)
        CURRENT_MODEL=$(get_current_llm_model)
        CURRENT_KEY=$(get_current_llm_api_key)
        
        echo -e "${WHITE}"
        echo "Current LLM Configuration:"
        echo "----------------------------------------"
        
        if [[ -n "$CURRENT_PROVIDER" ]]; then
          echo "  Provider: ${CURRENT_PROVIDER}"
          if [[ -n "$CURRENT_LLM_PROVIDER" ]]; then
            echo -e "    ${GRAY}(session override)${NC}"
          fi
        else
          echo -e "  Provider: ${GRAY}Not configured${NC}"
          echo -e "${GRAY}  Use 'spanner-shell --llm-setup' to configure${NC}"
        fi
        
        if [[ -n "$CURRENT_MODEL" ]]; then
          echo "  Model: ${CURRENT_MODEL}"
          if [[ -n "$CURRENT_LLM_MODEL" ]]; then
            echo -e "    ${GRAY}(session override)${NC}"
          fi
        else
          echo -e "  Model: ${GRAY}Not configured${NC}"
        fi
        
        if [[ -n "$CURRENT_KEY" ]]; then
          KEY_PREVIEW="${CURRENT_KEY:0:20}..."
          echo "  API Token: ${KEY_PREVIEW}"
          if [[ -n "$CURRENT_LLM_API_KEY" ]]; then
            echo -e "    ${GRAY}(session override)${NC}"
          fi
        else
          echo -e "  API Token: ${GRAY}Not configured${NC}"
        fi
        
        echo -e "${NC}"
        ;;
      
      "select")
        # Load available LLM configurations
        if [[ ! -f "$LLM_CONFIG_FILE" ]]; then
          echo -e "${RED}❌ No LLM configuration found.${NC}"
          echo -e "${WHITE}➡️  Configure with: spanner-shell --llm-setup${NC}"
          save_to_history "$SQL"
          continue
        fi
        
        # For now, we only have one global LLM config
        # In the future, this could support multiple LLMs
        source "$LLM_CONFIG_FILE"
        
        echo -e "${WHITE}"
        echo "Selecting LLM Configuration:"
        echo "----------------------------------------"
        echo "  1) Use global configuration (${LLM_PROVIDER} - ${LLM_MODEL})"
        echo "  2) Cancel"
        echo
        read -p "$(echo -e "${WHITE}Select option (1-2): ${NC}")" SELECT_CHOICE
        
        case "$SELECT_CHOICE" in
          1)
            CURRENT_LLM_PROVIDER="$LLM_PROVIDER"
            CURRENT_LLM_MODEL="$LLM_MODEL"
            CURRENT_LLM_API_KEY="$LLM_API_KEY"
            echo -e "${GREEN}✅ LLM configuration selected: ${LLM_PROVIDER} - ${LLM_MODEL}${NC}"
            ;;
          2)
            echo -e "${GRAY}Cancelled.${NC}"
            ;;
          *)
            echo -e "${RED}❌ Invalid option.${NC}"
            ;;
        esac
        echo -e "${NC}"
        ;;
      
      *)
        echo -e "${RED}❌ Unknown command: ${LLM_CMD}${NC}"
        echo -e "${WHITE}Available commands:${NC}"
        echo -e "${WHITE}  \\llm show     → Show current LLM configuration${NC}"
        echo -e "${WHITE}  \\llm select   → Select LLM configuration${NC}"
        ;;
    esac
    
    save_to_history "$SQL"
    continue
  fi

  # \hotspot-ai <table>
  if [[ "$SQL" =~ ^\\hotspot-ai[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    
    # Validate table exists
    TABLE_CHECK=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_name = '${TABLE_NAME}';" 2>/dev/null)
    
    if [[ ! "$TABLE_CHECK" =~ [1-9] ]]; then
      echo -e "${RED}❌ Table '${TABLE_NAME}' not found.${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Check dependencies
    if ! command -v curl >/dev/null 2>&1; then
      echo -e "${RED}❌ curl is not installed.${NC}"
      echo -e "${WHITE}➡️  Install with:${NC}"
      echo -e "${GRAY}   macOS: brew install curl${NC}"
      echo -e "${GRAY}   Linux: sudo apt-get install curl${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
      echo -e "${RED}❌ jq is not installed.${NC}"
      echo -e "${WHITE}➡️  Install with:${NC}"
      echo -e "${GRAY}   macOS: brew install jq${NC}"
      echo -e "${GRAY}   Linux: sudo apt-get install jq${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Check LLM configuration
    CURRENT_PROVIDER=$(get_current_llm_provider)
    CURRENT_MODEL=$(get_current_llm_model)
    CURRENT_KEY=$(get_current_llm_api_key)
    
    if [[ -z "$CURRENT_KEY" ]]; then
      echo -e "${RED}❌ LLM not configured.${NC}"
      echo -e "${WHITE}➡️  Configure with: spanner-shell --llm-setup${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    if [[ "$CURRENT_PROVIDER" != "openai" ]]; then
      echo -e "${RED}❌ Only OpenAI is supported at this time.${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Show progress
    echo -e "${WHITE}🔍 Analyzing hotspot risks for table '${TABLE_NAME}'...${NC}"
    echo -e "${GRAY}   This may take a few seconds...${NC}"
    echo
    
    # Get full database DDL
    FULL_DDL=$(get_full_database_ddl)
    if [[ -z "$FULL_DDL" ]]; then
      echo -e "${RED}❌ Error obtaining DDL.${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Get table metadata
    TABLE_METADATA=$(get_table_metadata "$TABLE_NAME")
    if [[ -z "$TABLE_METADATA" ]]; then
      echo -e "${RED}❌ Error obtaining table metadata.${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Build prompt
    PROMPT=$(build_hotspot_prompt "$FULL_DDL" "$TABLE_NAME" "$TABLE_METADATA")
    
    # Call OpenAI API
    echo -e "${GRAY}   Calling LLM...${NC}"
    LLM_RESPONSE=$(call_openai_api "$PROMPT" "$CURRENT_MODEL" "$CURRENT_KEY" 2>&1)
    API_STATUS=$?
    
    if [[ $API_STATUS -ne 0 ]]; then
      echo -e "${RED}❌ Error calling LLM API:${NC}"
      echo -e "${RED}${LLM_RESPONSE}${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Format and display report
    format_hotspot_report "$LLM_RESPONSE"
    
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
        echo -e "${RED}❌ Error: ${FORMATTED_ERROR}${NC}"
      else
        echo -e "${RED}❌ Error listing tables.${NC}"
      fi
    else
      if [[ -n "$TABLE_OUTPUT" && ! "$TABLE_OUTPUT" =~ ^[[:space:]]*$ ]]; then
        format_table "$TABLE_OUTPUT" 0 false
      else
        echo -e "${GRAY}No tables found.${NC}"
      fi
    fi

    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \da (must be checked before \dd <table>)
  if [[ "$SQL" == "\\da" ]] || [[ "$SQL" =~ ^\\da[[:space:]]*$ ]]; then
    echo -e "${WHITE}"
    gcloud spanner databases ddl describe ${DATABASE_ID} \
      --instance=${INSTANCE_ID}
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \dd <table>
  if [[ "$SQL" =~ ^\\dd[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    echo -e "${WHITE}"
    DDL_OUTPUT=$(gcloud spanner databases ddl describe ${DATABASE_ID} \
      --instance=${INSTANCE_ID} 2>/dev/null)
    
    # Extract DDL of the specific table
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
      echo "Table '${TABLE_NAME}' not found in DDL."
    fi
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \d <table>
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
        echo -e "${RED}❌ Error: ${FORMATTED_ERROR}${NC}"
      else
        echo -e "${RED}❌ Error describing table '${TABLE_NAME}'.${NC}"
      fi
    else
      if [[ -n "$COLUMNS_OUTPUT" && ! "$COLUMNS_OUTPUT" =~ ^[[:space:]]*$ ]]; then
        format_table "$COLUMNS_OUTPUT" 0 false
      else
        echo -e "${GRAY}Table '${TABLE_NAME}' not found or has no columns.${NC}"
      fi
    fi

    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \n <table>
  if [[ "$SQL" =~ ^\\n[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    echo -e "${WHITE}"
    echo "Counting records in table '${TABLE_NAME}'..."
    gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT COUNT(*) as total FROM ${TABLE_NAME};"
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \s <table> [n]
  if [[ "$SQL" =~ ^\\s[[:space:]]+([a-zA-Z0-9_]+)([[:space:]]+([0-9]+))?$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    SAMPLE_SIZE="${BASH_REMATCH[3]:-10}"  # Default: 10 if not specified
    
    # Validate sample size
    if [[ "$SAMPLE_SIZE" -lt 1 || "$SAMPLE_SIZE" -gt 1000 ]]; then
      echo -e "${RED}❌ Sample size must be between 1 and 1000${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Execute query and capture output
    TABLE_OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT * FROM ${TABLE_NAME} LIMIT ${SAMPLE_SIZE};" 2>&1)
    
    STATUS=$?
    
    if [ $STATUS -ne 0 ]; then
      ERROR_MSG=$(echo "$TABLE_OUTPUT" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
      if [ -n "$ERROR_MSG" ]; then
        FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
        echo -e "${RED}❌ Error: ${FORMATTED_ERROR}${NC}"
      else
        echo -e "${RED}❌ Error executing query on table '${TABLE_NAME}'.${NC}"
      fi
    else
      if [[ -n "$TABLE_OUTPUT" && ! "$TABLE_OUTPUT" =~ ^[[:space:]]*$ ]]; then
        echo -e "${WHITE}"
        echo "Showing ${SAMPLE_SIZE} records from table '${TABLE_NAME}':"
        echo "----------------------------------------"
        format_table "$TABLE_OUTPUT" 0 true
      else
        echo -e "${GRAY}No records found in table '${TABLE_NAME}'.${NC}"
      fi
    fi
    
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \f <table> [n] [column] (must be checked before basic \l)
  if [[ "$SQL" =~ ^\\f[[:space:]]+([a-zA-Z0-9_]+)([[:space:]]+([0-9]+))?([[:space:]]+([a-zA-Z0-9_]+))?$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    TAIL_SIZE="${BASH_REMATCH[3]:-10}"
    ORDER_COLUMN="${BASH_REMATCH[5]}"
    
    # Validate size
    if [[ "$TAIL_SIZE" -lt 1 || "$TAIL_SIZE" -gt 1000 ]]; then
      echo -e "${RED}❌ Number of records must be between 1 and 1000${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Determine ordering column
    if [[ -z "$ORDER_COLUMN" ]]; then
      ORDER_COLUMN=$(get_default_order_column "$TABLE_NAME")
      if [[ -z "$ORDER_COLUMN" ]]; then
        echo -e "${RED}❌ Could not determine ordering column for table '${TABLE_NAME}'${NC}"
        save_to_history "$SQL"
        continue
      fi
    else
      # Validate if column exists
      if ! validate_column_exists "$TABLE_NAME" "$ORDER_COLUMN"; then
        echo -e "${RED}❌ Column '${ORDER_COLUMN}' not found in table '${TABLE_NAME}'${NC}"
        save_to_history "$SQL"
        continue
      fi
    fi
    
    # Get type of ordering column
    COLUMN_TYPE=$(get_column_type "$TABLE_NAME" "$ORDER_COLUMN")
    
    echo -e "${WHITE}"
    echo "Monitoring new records in table '${TABLE_NAME}' (every 5 seconds)..."
    echo "Ordered by: ${ORDER_COLUMN} (${COLUMN_TYPE})"
    echo "Press Ctrl+C to stop"
    echo "----------------------------------------"
    echo -e "${NC}"
    
    # Variable to store last seen value
    LAST_VALUE=""
    FIRST_RUN=true
    
    # Handler for interruption
    tail_interrupted=false
    tail_interrupt_handler() {
      tail_interrupted=true
      echo ""
      echo -e "${GREEN}✅ Monitoring interrupted${NC}"
    }
    trap tail_interrupt_handler SIGINT
    
    while true; do
      # Check if interrupted
      if [[ "$tail_interrupted" == true ]]; then
        trap - SIGINT  # Remove handler
        break
      fi
      
      # Build SQL query
      if [[ "$FIRST_RUN" == true ]]; then
        # First execution: show last N records and get the highest value
        SQL_QUERY="SELECT * FROM ${TABLE_NAME} ORDER BY ${ORDER_COLUMN} DESC LIMIT ${TAIL_SIZE};"
        FIRST_RUN=false
      else
        # Subsequent executions: show only new records
        if [[ -n "$LAST_VALUE" ]]; then
          # Build comparison based on type
          case "$COLUMN_TYPE" in
            "STRING"|"BYTES"|"DATE"|"TIMESTAMP")
              SQL_QUERY="SELECT * FROM ${TABLE_NAME} WHERE ${ORDER_COLUMN} > '${LAST_VALUE}' ORDER BY ${ORDER_COLUMN} DESC LIMIT ${TAIL_SIZE};"
              ;;
            "INT64"|"FLOAT64")
              SQL_QUERY="SELECT * FROM ${TABLE_NAME} WHERE ${ORDER_COLUMN} > ${LAST_VALUE} ORDER BY ${ORDER_COLUMN} DESC LIMIT ${TAIL_SIZE};"
              ;;
            *)
              # For other types, try with quotes
              SQL_QUERY="SELECT * FROM ${TABLE_NAME} WHERE ${ORDER_COLUMN} > '${LAST_VALUE}' ORDER BY ${ORDER_COLUMN} DESC LIMIT ${TAIL_SIZE};"
              ;;
          esac
        else
          SQL_QUERY="SELECT * FROM ${TABLE_NAME} ORDER BY ${ORDER_COLUMN} DESC LIMIT ${TAIL_SIZE};"
        fi
      fi
      
      # Execute query
      OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
        --instance=${INSTANCE_ID} \
        --quiet \
        --sql="$SQL_QUERY" 2>&1)
      
      STATUS=$?
      
      if [ $STATUS -eq 0 ]; then
        # Check if there are results
        if [[ -n "$OUTPUT" && ! "$OUTPUT" =~ ^[[:space:]]*$ ]]; then
          # Get the highest value of the ordering column from current results
          # Make a simple query that returns only the current highest value
          MAX_VALUE_QUERY="SELECT ${ORDER_COLUMN} FROM ${TABLE_NAME} ORDER BY ${ORDER_COLUMN} DESC LIMIT 1;"
          MAX_OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
            --instance=${INSTANCE_ID} \
            --quiet \
            --sql="$MAX_VALUE_QUERY" 2>/dev/null)
          
          # Extract maximum value (skip header)
          NEW_LAST_VALUE=""
          if [[ -n "$MAX_OUTPUT" ]]; then
            MAX_LINE=$(echo "$MAX_OUTPUT" | grep -v "^${ORDER_COLUMN}" | grep -v "^$" | head -n 1)
            if [[ -n "$MAX_LINE" ]]; then
              NEW_LAST_VALUE=$(echo "$MAX_LINE" | awk '{print $1}' | sed "s/'//g" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            fi
          fi
          
          # Show results if first execution or if there are new records
          if [[ -z "$LAST_VALUE" ]]; then
            # First execution: show all last N records
            format_table "$OUTPUT" 0 true
            if [[ -n "$NEW_LAST_VALUE" && "$NEW_LAST_VALUE" != "NULL" ]]; then
              LAST_VALUE="$NEW_LAST_VALUE"
            fi
          elif [[ -n "$NEW_LAST_VALUE" && "$NEW_LAST_VALUE" != "NULL" && "$NEW_LAST_VALUE" != "$LAST_VALUE" ]]; then
            # Subsequent executions: show only if there are new records
            echo -e "${GREEN}[$(date +%H:%M:%S)] New records found:${NC}"
            format_table "$OUTPUT" 0 true
            LAST_VALUE="$NEW_LAST_VALUE"
          fi
        fi
      else
        # In case of error, try to extract message
        ERROR_MSG=$(echo "$OUTPUT" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
        if [[ -n "$ERROR_MSG" ]]; then
          FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
          echo -e "${RED}❌ Error: ${FORMATTED_ERROR}${NC}"
        else
          echo -e "${RED}❌ Error executing query${NC}"
        fi
        # Continue even with error
      fi
      
      # Wait 5 seconds
      sleep 5
    done
    
    trap - SIGINT  # Remove handler on exit
    save_to_history "$SQL"
    continue
  fi

  # \l <table> [n] [column]
  if [[ "$SQL" =~ ^\\l[[:space:]]+([a-zA-Z0-9_]+)([[:space:]]+([0-9]+))?([[:space:]]+([a-zA-Z0-9_]+))?$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    TAIL_SIZE="${BASH_REMATCH[3]:-10}"
    ORDER_COLUMN="${BASH_REMATCH[5]}"
    
    # Validate size
    if [[ "$TAIL_SIZE" -lt 1 || "$TAIL_SIZE" -gt 1000 ]]; then
      echo -e "${RED}❌ Number of records must be between 1 and 1000${NC}"
      save_to_history "$SQL"
      continue
    fi
    
    # Determine ordering column
    if [[ -z "$ORDER_COLUMN" ]]; then
      ORDER_COLUMN=$(get_default_order_column "$TABLE_NAME")
      if [[ -z "$ORDER_COLUMN" ]]; then
        echo -e "${RED}❌ Could not determine ordering column for table '${TABLE_NAME}'${NC}"
        save_to_history "$SQL"
        continue
      fi
    else
      # Validate if column exists
      if ! validate_column_exists "$TABLE_NAME" "$ORDER_COLUMN"; then
        echo -e "${RED}❌ Column '${ORDER_COLUMN}' not found in table '${TABLE_NAME}'${NC}"
        save_to_history "$SQL"
        continue
      fi
    fi
    
    # Execute query and capture output
    TABLE_OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="SELECT * FROM ${TABLE_NAME} ORDER BY ${ORDER_COLUMN} DESC LIMIT ${TAIL_SIZE};" 2>&1)
    
    STATUS=$?
    
    if [ $STATUS -ne 0 ]; then
      ERROR_MSG=$(echo "$TABLE_OUTPUT" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
      if [ -n "$ERROR_MSG" ]; then
        FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
        echo -e "${RED}❌ Error: ${FORMATTED_ERROR}${NC}"
      else
        echo -e "${RED}❌ Error executing query on table '${TABLE_NAME}'.${NC}"
      fi
    else
      if [[ -n "$TABLE_OUTPUT" && ! "$TABLE_OUTPUT" =~ ^[[:space:]]*$ ]]; then
        echo -e "${WHITE}"
        echo "Showing last ${TAIL_SIZE} records from table '${TABLE_NAME}' (ordered by ${ORDER_COLUMN}):"
        echo "----------------------------------------"
        format_table "$TABLE_OUTPUT" 0 true
      else
        echo -e "${GRAY}No records found in table '${TABLE_NAME}'.${NC}"
      fi
    fi
    
    echo -e "${NC}"
    save_to_history "$SQL"
    continue
  fi

  # \g <table>
  if [[ "$SQL" =~ ^\\g[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
    TABLE_NAME="${BASH_REMATCH[1]}"
    generate_dml_examples "$TABLE_NAME"
    save_to_history "$SQL"
    continue
  fi

# =========================================
# ✅ COMMAND: \repeat <n> <command>
# =========================================
if [[ "$SQL" =~ ^\\r[[:space:]]+([0-9]+)[[:space:]]+(.+)$ ]]; then
  REPEAT_COUNT="${BASH_REMATCH[1]}"
  REPEAT_CMD="${BASH_REMATCH[2]}"
  
  # Remove ANSI codes from command
  REPEAT_CMD=$(clean_ansi "$REPEAT_CMD")
  REPEAT_CMD=$(clean_ansi "$REPEAT_CMD")
  # Remove leading and trailing spaces
  REPEAT_CMD=$(printf '%s' "$REPEAT_CMD" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  # Remove external quotes if they exist (single or double)
  if [[ "$REPEAT_CMD" =~ ^\"(.*)\"$ ]]; then
    REPEAT_CMD="${BASH_REMATCH[1]}"
  elif [[ "$REPEAT_CMD" =~ ^\'(.*)\'$ ]]; then
    REPEAT_CMD="${BASH_REMATCH[1]}"
  fi
  
  # Validate number of repetitions
  if [[ "$REPEAT_COUNT" -lt 1 || "$REPEAT_COUNT" -gt 100 ]]; then
    echo -e "${RED}❌ Number of repetitions must be between 1 and 100${NC}"
    save_to_history "$SQL"
    continue
  fi
  
  echo -e "${WHITE}"
  echo "Executing command ${REPEAT_COUNT} time(s):"
  echo "----------------------------------------"
  
  # Show full command first time (truncated if too long)
  if [[ ${#REPEAT_CMD} -gt 80 ]]; then
    echo -e "${GRAY}Command:${NC} ${WHITE}${REPEAT_CMD:0:77}...${NC}"
  else
    echo -e "${GRAY}Command:${NC} ${WHITE}${REPEAT_CMD}${NC}"
  fi
  echo
  
  for ((i=1; i<=REPEAT_COUNT; i++)); do
    echo -e "${GRAY}[${i}/${REPEAT_COUNT}]${NC}"
    
    # Execute command as SQL (assumes it's a SQL query)
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
        echo -e "${RED}❌ Error: ${FORMATTED_ERROR}${NC}"
      else
        FORMATTED_ERROR=$(format_error_message "$OUTPUT")
        echo -e "${RED}❌ Error: ${FORMATTED_ERROR}${NC}"
      fi
    else
      echo "$OUTPUT"
    fi
    echo -e "${NC}"
    
    # Add separator between executions (except on last)
    if [[ $i -lt $REPEAT_COUNT ]]; then
      echo "----------------------------------------"
    fi
  done
  
  echo
  save_to_history "$SQL"
  continue
fi

# =========================================
# ✅ COMMAND: \import-ddl <file.sql>
# =========================================
if [[ "$SQL" =~ ^\\id($|[[:space:]]+) ]]; then

  # Remove command "\id" and capture only the path
  FILE_PATH="$(echo "$SQL" | sed 's/^\\id[[:space:]]*//')"

  # ✅ 1. Validate if path was provided
  if [[ -z "$FILE_PATH" ]]; then
    echo -e "${RED}❌ Correct usage: \\id <file-path.sql>${NC}"
    continue
  fi

  # ✅ 2. Validate if file exists
  if [[ ! -f "$FILE_PATH" ]]; then
    echo -e "${RED}❌ File not found: ${FILE_PATH}${NC}"
    continue
  fi

  # ✅ 3. Execute file
  echo -e "${WHITE}📂 Loading file: ${FILE_PATH}${NC}"
  echo

  gcloud spanner databases ddl update ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --ddl="$(cat "$FILE_PATH")"

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ File imported successfully!${NC}"
  else
    echo -e "${RED}❌ Error executing file.${NC}"
  fi

  save_to_history "$SQL"
  continue
fi

# =========================================
# ✅ COMMAND: \import <file.sql>
# =========================================
if [[ "$SQL" =~ ^\\im($|[[:space:]]+) ]]; then

  # Remove command "\im" and capture only the path
  FILE_PATH="$(echo "$SQL" | sed 's/^\\im[[:space:]]*//')"

  # ✅ 1. Validate if path was provided
  if [[ -z "$FILE_PATH" ]]; then
    echo -e "${RED}❌ Correct usage: \\im <file-path.sql>${NC}"
    continue
  fi

  # ✅ 2. Validate if file exists
  if [[ ! -f "$FILE_PATH" ]]; then
    echo -e "${RED}❌ File not found: ${FILE_PATH}${NC}"
    continue
  fi

  # ✅ 3. Execute file
  echo -e "${WHITE}📂 Loading file: ${FILE_PATH}${NC}"
  echo

  gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="$(cat "$FILE_PATH")"

  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ File imported successfully!${NC}"
  else
    echo -e "${RED}❌ Error executing file.${NC}"
  fi

  save_to_history "$SQL"
  continue
fi

# =========================================
# ✅ COMMAND: \pk <table>
# =========================================
if [[ "$SQL" =~ ^\\k[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
  TABLE_NAME="${BASH_REMATCH[1]}"

  echo -e "${WHITE}🔑 Primary Key of table: ${TABLE_NAME}${NC}"
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
      echo -e "${RED}❌ Error: ${FORMATTED_ERROR}${NC}"
    else
      echo -e "${RED}❌ Error fetching PK.${NC}"
    fi
    echo
    continue
  fi

  # Remove gcloud header (if present)
  PK_COLUMNS=$(echo "$OUTPUT" | tail -n +2)

  if [ -z "$PK_COLUMNS" ]; then
    echo -e "${GRAY}⚠️  No PK found for table '${TABLE_NAME}'.${NC}"
  else
    echo "$PK_COLUMNS"
  fi

  echo
  continue
fi


# =========================================
# ✅ COMMAND: \indexes <table>
# =========================================
if [[ "$SQL" =~ ^\\i[[:space:]]+([a-zA-Z0-9_]+)$ ]]; then
  TABLE_NAME="${BASH_REMATCH[1]}"

  echo -e "${WHITE}📑 Indexes of table: ${TABLE_NAME}${NC}"
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
      echo -e "${RED}❌ Error: ${FORMATTED_ERROR}${NC}"
    else
      echo -e "${RED}❌ Error fetching indexes.${NC}"
    fi

    echo
    continue
  fi

  RESULT=$(echo "$OUTPUT" | tail -n +2)

  if [ -z "$RESULT" ]; then
    echo -e "${GRAY}⚠️  No indexes found for table '${TABLE_NAME}'.${NC}"
    echo
    continue
  fi

  CURRENT_INDEX=""
  echo "$RESULT" | while read -r INDEX_NAME INDEX_TYPE COLUMN_NAME ORDINAL; do
    if [[ "$INDEX_NAME" != "$CURRENT_INDEX" ]]; then
      echo
      echo -e "${GREEN}🔹 Index: ${INDEX_NAME} (${INDEX_TYPE})${NC}"
      CURRENT_INDEX="$INDEX_NAME"
    fi
    echo "   - ${COLUMN_NAME}"
  done

  echo
  continue
fi

# =========================================
# ✅ COMMAND: \diff <table> <id1> <id2>
# =========================================
if [[ "$SQL" =~ ^\\df($|[[:space:]]+) ]]; then

  # Remove command "\df" and capture only parameters
  PARAMS=$(echo "$SQL" | sed 's/^\\df[[:space:]]*//')

  # ✅ Validate number of parameters
  PARAM_COUNT=$(echo "$PARAMS" | wc -w | tr -d ' ')

  if [[ $PARAM_COUNT -ne 3 ]]; then
    echo -e "${RED}❌ Correct usage: \\df <table> <id1> <id2>${NC}"
    continue
  fi

  TABLE_NAME=$(echo "$PARAMS" | awk '{print $1}')
  ID1_RAW=$(echo "$PARAMS" | awk '{print $2}')
  ID2_RAW=$(echo "$PARAMS" | awk '{print $3}')

  # Check if jq is installed
  if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}❌ jq is not installed.${NC}"
    echo -e "${WHITE}➡️  Install with:${NC}"
    echo -e "${GRAY}   macOS: brew install jq${NC}"
    echo -e "${GRAY}   Linux: sudo apt-get install jq (or sudo yum install jq)${NC}"
    continue
  fi

  echo -e "${WHITE}🔍 Comparing records from table: ${TABLE_NAME}${NC}"
  echo "   ID1: ${ID1_RAW}"
  echo "   ID2: ${ID2_RAW}"
  echo

  # =========================================
  # 🔎 DETECT PK TYPE (STRING or INT64)
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
    echo -e "${RED}❌ Could not detect table PK.${NC}"
    continue
  fi

  # =========================================
  # 🔐 ADJUST ID FORMAT ACCORDING TO TYPE
  # =========================================
  if [[ "$PK_TYPE" == "STRING" ]]; then
    ID1="'${ID1_RAW}'"
    ID2="'${ID2_RAW}'"
  else
    # INT64
    if [[ ! "$ID1_RAW" =~ ^[0-9]+$ || ! "$ID2_RAW" =~ ^[0-9]+$ ]]; then
      echo -e "${RED}❌ PK is numeric (INT64). IDs must be numbers.${NC}"
      continue
    fi
    ID1="${ID1_RAW}"
    ID2="${ID2_RAW}"
  fi

  # =========================================
  # 🔎 GET COLUMN NAMES FROM TABLE
  # =========================================
  COLUMNS_INFO=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="SELECT column_name FROM information_schema.columns WHERE table_name = '${TABLE_NAME}' ORDER BY ordinal_position;" 2>/dev/null)

  # Extract column names (skip header)
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
    echo -e "${RED}❌ Could not get table columns.${NC}"
    continue
  fi

  # =========================================
  # 🔎 FETCH THE TWO RECORDS
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

  # Check if there was an execution error
  if [[ "$ROW1_RAW" =~ "ERROR" ]] || [[ "$ROW2_RAW" =~ "ERROR" ]]; then
    echo -e "${RED}❌ Error fetching records.${NC}"
    continue
  fi

  # =========================================
  # 🔄 CONVERT VALUE ARRAYS TO JSON OBJECTS
  # gcloud returns value arrays, we need to combine them with column names
  # =========================================
  # Extract first value array
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

  # Check if arrays were extracted successfully
  if [[ -z "$ARRAY1" || -z "$ARRAY2" || "$ARRAY1" == "null" || "$ARRAY2" == "null" || "$ARRAY1" == "" || "$ARRAY2" == "" ]]; then
    # Check if it's because records don't exist
    ROW1_CHECK=$(echo "$ROW1_RAW" | jq 'if type == "array" then length elif type == "object" and has("rows") then (.rows | length) else 0 end' 2>/dev/null || echo "0")
    ROW2_CHECK=$(echo "$ROW2_RAW" | jq 'if type == "array" then length elif type == "object" and has("rows") then (.rows | length) else 0 end' 2>/dev/null || echo "0")
    
    if [[ "$ROW1_CHECK" == "0" || "$ROW2_CHECK" == "0" ]]; then
      echo -e "${RED}❌ One or both records do not exist.${NC}"
    else
      echo -e "${RED}❌ Error processing record data.${NC}"
    fi
    continue
  fi

  # Build JSON objects combining column names with values
  # Create a JSON object where each key is the column name and the value comes from the array
  J1_OBJ="{"
  J2_OBJ="{"
  
  for i in "${!COLUMN_NAMES[@]}"; do
    COL_NAME="${COLUMN_NAMES[$i]}"
    
    # Extract value from array at position i
    VAL1=$(echo "$ARRAY1" | jq -c ".[$i]" 2>/dev/null)
    VAL2=$(echo "$ARRAY2" | jq -c ".[$i]" 2>/dev/null)
    
    # Add comma if not first field
    if [[ $i -gt 0 ]]; then
      J1_OBJ+=","
      J2_OBJ+=","
    fi
    
    # Add field to JSON object
    J1_OBJ+="\"$COL_NAME\":$VAL1"
    J2_OBJ+="\"$COL_NAME\":$VAL2"
  done
  
  J1_OBJ+="}"
  J2_OBJ+="}"

  # Validate if JSON objects are valid
  J1=$(echo "$J1_OBJ" | jq '.' 2>/dev/null)
  J2=$(echo "$J2_OBJ" | jq '.' 2>/dev/null)

  if [[ -z "$J1" || -z "$J2" || "$J1" == "null" || "$J2" == "null" ]]; then
    echo -e "${RED}❌ Error building JSON objects for comparison.${NC}"
    continue
  fi

  echo -e "${GREEN}📊 Differences found:${NC}"
  echo

  DIFF_FOUND=false

  # Compare each field
  for FIELD in "${COLUMN_NAMES[@]}"; do
    # Extract values using jq
    V1=$(echo "$J1" | jq -c --arg field "$FIELD" '.[$field]' 2>/dev/null)
    V2=$(echo "$J2" | jq -c --arg field "$FIELD" '.[$field]' 2>/dev/null)

    # Compare values (considers null as valid value)
    if [[ "$V1" != "$V2" ]]; then
      DIFF_FOUND=true
      echo "• ${FIELD}:"
      echo "    ${ID1_RAW} → ${V1}"
      echo "    ${ID2_RAW} → ${V2}"
      echo
    fi
  done

  if [[ "$DIFF_FOUND" == false ]]; then
    echo -e "${GRAY}✅ Records are identical.${NC}"
  fi

  continue
fi
# =========================================
# ✅ COMMAND: \export <query> --format csv|json --output <file>
# =========================================
if [[ "$SQL" =~ ^\\e[[:space:]]+ ]]; then
  # Remove command "\e" from beginning
  export_cmd=$(echo "$SQL" | sed 's/^\\e[[:space:]]*//')
  
  # Extract SQL query (may be in quotes or not)
  query=""
  format=""
  output_file=""
  
  # Try to extract query between double quotes
  if [[ "$export_cmd" =~ ^\"([^\"]+)\" ]]; then
    query="${BASH_REMATCH[1]}"
    export_cmd=$(echo "$export_cmd" | sed 's/^"[^"]*"[[:space:]]*//')
  # Try to extract query between single quotes
  elif [[ "$export_cmd" =~ ^\'([^\']+)\' ]]; then
    query="${BASH_REMATCH[1]}"
    export_cmd=$(echo "$export_cmd" | sed "s/^'[^']*'[[:space:]]*//")
  else
    # Query without quotes - extract until finding --format
    if [[ "$export_cmd" =~ ^([^[:space:]]+[[:space:]]+.*?)[[:space:]]+--format ]]; then
      query=$(echo "$export_cmd" | sed 's/[[:space:]]*--format.*$//')
      export_cmd=$(echo "$export_cmd" | sed 's/^.*[[:space:]]*--format[[:space:]]*//')
    else
      # Simple query without --format (error)
      query=""
    fi
  fi
  
  # Extract --format
  if [[ "$export_cmd" =~ ^(csv|json)[[:space:]]+ ]]; then
    format="${BASH_REMATCH[1]}"
    export_cmd=$(echo "$export_cmd" | sed 's/^[^[:space:]]*[[:space:]]*//')
  elif [[ "$export_cmd" =~ ^--format[[:space:]]+(csv|json)[[:space:]]+ ]]; then
    format="${BASH_REMATCH[1]}"
    export_cmd=$(echo "$export_cmd" | sed 's/^--format[[:space:]]*[^[:space:]]*[[:space:]]*//')
  fi
  
  # Extract --output
  if [[ "$export_cmd" =~ ^--output[[:space:]]+([^[:space:]]+) ]]; then
    output_file="${BASH_REMATCH[1]}"
  elif [[ "$export_cmd" =~ ^([^[:space:]]+) ]]; then
    # If no --output, assume next token is the file
    output_file="${BASH_REMATCH[1]}"
  fi
  
  # Validations
  if [[ -z "$query" ]]; then
    echo -e "${RED}❌ SQL query not provided.${NC}"
    echo -e "${WHITE}Usage: \\e \"<query>\" --format csv|json --output <file>${NC}"
    save_to_history "$SQL"
    continue
  fi
  
  if [[ -z "$format" || ! "$format" =~ ^(csv|json)$ ]]; then
    echo -e "${RED}❌ Invalid format. Must be 'csv' or 'json'.${NC}"
    save_to_history "$SQL"
    continue
  fi
  
  if [[ -z "$output_file" ]]; then
    echo -e "${RED}❌ Output file not provided.${NC}"
    save_to_history "$SQL"
    continue
  fi
  
  # Validate output directory
  output_dir=$(dirname "$output_file")
  if [[ -n "$output_dir" && "$output_dir" != "." ]]; then
    if [[ ! -d "$output_dir" ]]; then
      if ! mkdir -p "$output_dir" 2>/dev/null; then
        echo -e "${RED}❌ Could not create directory: ${output_dir}${NC}"
        save_to_history "$SQL"
        continue
      fi
    fi
  fi
  
  # Check if file already exists
  if [[ -f "$output_file" ]]; then
    echo -e "${GRAY}⚠️  File already exists: ${output_file}${NC}"
    echo -e "${GRAY}   Will be overwritten.${NC}"
  fi
  
  # Execute query
  echo -e "${WHITE}Executing query...${NC}"
  
  if [[ "$format" == "json" ]]; then
    # Execute with JSON format
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
        echo -e "${RED}❌ Error: ${FORMATTED_ERROR}${NC}"
      else
        echo -e "${RED}❌ Error executing query.${NC}"
      fi
      save_to_history "$SQL"
      continue
    fi
    
    # Export to JSON
    line_count=$(export_to_json "$json_output" "$output_file")
    
    if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}✅ Exported successfully: ${output_file} (${line_count} record(s))${NC}"
    else
      echo -e "${RED}❌ Error saving JSON file.${NC}"
    fi
  else
    # Execute with tabular format (CSV)
    csv_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
      --instance=${INSTANCE_ID} \
      --quiet \
      --sql="$query" 2>&1)
    
    STATUS=$?
    
    if [[ $STATUS -ne 0 ]]; then
      ERROR_MSG=$(echo "$csv_output" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
      if [[ -n "$ERROR_MSG" ]]; then
        FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
        echo -e "${RED}❌ Error: ${FORMATTED_ERROR}${NC}"
      else
        echo -e "${RED}❌ Error executing query.${NC}"
      fi
      save_to_history "$SQL"
      continue
    fi
    
    # Export to CSV
    # Use temporary file to capture stderr separately
    temp_stderr=$(mktemp)
    line_count=$(export_to_csv "$csv_output" "$output_file" 2>"$temp_stderr")
    export_status=$?
    error_msg=$(cat "$temp_stderr" 2>/dev/null)
    rm -f "$temp_stderr"
    
    if [[ $export_status -eq 0 && -n "$line_count" && "$line_count" =~ ^[0-9]+$ ]]; then
      echo -e "${GREEN}✅ Exported successfully: ${output_file} (${line_count} line(s))${NC}"
    else
      if [[ -n "$error_msg" ]]; then
        echo -e "${RED}❌ $error_msg${NC}"
      else
        echo -e "${RED}❌ Error saving CSV file.${NC}"
      fi
    fi
  fi
  
  echo -e "${NC}"
  save_to_history "$SQL"
  continue
fi
# =========================================
# ✅ COMMAND: \pagination <query> [--page-size <n>]
# =========================================
if [[ "$SQL" =~ ^\\p[[:space:]]+ ]]; then
  # Remove command "\p" from beginning
  table_cmd=$(echo "$SQL" | sed 's/^\\p[[:space:]]*//')
  
  # Extract SQL query and options
  query=""
  page_size=20  # Default
  
  # Try to extract query between double quotes
  if [[ "$table_cmd" =~ ^\"([^\"]+)\" ]]; then
    query="${BASH_REMATCH[1]}"
    table_cmd=$(echo "$table_cmd" | sed 's/^"[^"]*"[[:space:]]*//')
  # Try to extract query between single quotes
  elif [[ "$table_cmd" =~ ^\'([^\']+)\' ]]; then
    query="${BASH_REMATCH[1]}"
    table_cmd=$(echo "$table_cmd" | sed "s/^'[^']*'[[:space:]]*//")
  else
    # Query without quotes - extract until finding --page-size
    if [[ "$table_cmd" =~ ^([^[:space:]]+[[:space:]]+.*?)[[:space:]]+--page-size ]]; then
      query=$(echo "$table_cmd" | sed 's/[[:space:]]*--page-size.*$//')
      table_cmd=$(echo "$table_cmd" | sed 's/^.*[[:space:]]*--page-size[[:space:]]*//')
    else
      # Simple query without options
      query="$table_cmd"
      table_cmd=""
    fi
  fi
  
  # Extract --page-size
  if [[ "$table_cmd" =~ ^--page-size[[:space:]]+([0-9]+) ]]; then
    page_size="${BASH_REMATCH[1]}"
  elif [[ "$table_cmd" =~ ^([0-9]+) ]]; then
    page_size="${BASH_REMATCH[1]}"
  fi
  
  # Validations
  if [[ -z "$query" ]]; then
    echo -e "${RED}❌ SQL query not provided.${NC}"
    echo -e "${WHITE}Usage: \\p \"<query>\" [--page-size <n>]${NC}"
    save_to_history "$SQL"
    continue
  fi
  
  if [[ ! "$page_size" =~ ^[0-9]+$ ]] || [[ "$page_size" -lt 1 ]] || [[ "$page_size" -gt 100 ]]; then
    echo -e "${RED}❌ Invalid page size. Must be between 1 and 100.${NC}"
    save_to_history "$SQL"
    continue
  fi
  
  # Execute query
  echo -e "${WHITE}Executing query...${NC}"
  
  table_output=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="$query" 2>&1)
  
  STATUS=$?
  
  if [[ $STATUS -ne 0 ]]; then
    ERROR_MSG=$(echo "$table_output" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
    if [[ -n "$ERROR_MSG" ]]; then
      FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
      echo -e "${RED}❌ Error: ${FORMATTED_ERROR}${NC}"
    else
      echo -e "${RED}❌ Error executing query.${NC}"
    fi
    save_to_history "$SQL"
    continue
  fi
  
  # Check if there are results
  if [[ -z "$table_output" ]]; then
    echo -e "${GRAY}No results found.${NC}"
    save_to_history "$SQL"
    continue
  fi
  
  # Format and display table
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

  # Normal SQL
# =========================================
# ✅ EXECUTE NORMAL SQL WITH ERROR EXTRACTION
# =========================================
if [ -n "$SQL" ]; then
  echo -e "${WHITE}"

  OUTPUT=$(gcloud spanner databases execute-sql ${DATABASE_ID} \
    --instance=${INSTANCE_ID} \
    --quiet \
    --sql="$SQL" 2>&1)

  STATUS=$?

  if [ $STATUS -ne 0 ]; then
    # 🔹 Extract only the "message" field from JSON, if it exists
    ERROR_MSG=$(echo "$OUTPUT" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')

    if [ -n "$ERROR_MSG" ]; then
      FORMATTED_ERROR=$(format_error_message "$ERROR_MSG")
      echo -e "${RED}❌ Error: ${FORMATTED_ERROR}${NC}"
    else
      echo -e "${RED}❌ Error: ${OUTPUT}${NC}"
    fi
  else
    # Check if it's a SELECT command and if there are results
    if is_select_query "$SQL"; then
      # It's a SELECT: format as table without pagination
      if [[ -n "$OUTPUT" && ! "$OUTPUT" =~ ^[[:space:]]*$ ]]; then
        format_table "$OUTPUT" 0
      else
        echo -e "${GRAY}No results found.${NC}"
      fi
    else
      # Not SELECT: keep original behavior
      echo "$OUTPUT"
    fi
  fi

  echo -e "${NC}"
  # Save SQL command to history
  save_to_history "$SQL"
fi

done
