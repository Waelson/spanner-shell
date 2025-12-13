# 📋 Plano de Implementação: Comando `\hotspot-ai`

## 🎯 Objetivo
Implementar comando `\hotspot-ai <table>` que utiliza LLM configurada para analisar hotspots em tabelas do Google Cloud Spanner, identificando problemas de design que podem causar hotspots.

---

## 📐 Arquitetura da Solução

### Fluxo de Execução
```
\hotspot-ai <table>
    ↓
1. Validar tabela existe
    ↓
2. Obter DDL COMPLETA do banco de dados:
   - Todas as tabelas
   - Todos os índices
   - Todas as sequences
   - Todas as funções
   (usar \da internamente - DDL completa)
    ↓
3. Obter informações adicionais da tabela específica:
   - Primary Key e tipo
   - Índices secundários
   - Colunas e tipos
   - Default values (para detectar sequências)
    ↓
4. Verificar LLM configurada
    ↓
5. Construir prompt estruturado
   (incluir DDL completa + metadados da tabela)
    ↓
6. Chamar API OpenAI
    ↓
7. Processar resposta JSON
    ↓
8. Formatar saída (similar ao exemplo)
```

---

## 🔧 Componentes a Implementar

### 1. Função: `get_full_database_ddl()`
**Localização:** Após função `get_column_type()` (linha ~757)

**Responsabilidade:**
- Obter DDL COMPLETA do banco de dados usando `gcloud spanner databases ddl describe`
- Incluir TODOS os objetos:
  - Todas as tabelas (CREATE TABLE)
  - Todos os índices (CREATE INDEX)
  - Todas as sequences (CREATE SEQUENCE)
  - Todas as funções (CREATE FUNCTION)
- Retornar DDL completa como string

**Entrada:** Nenhuma (usa DATABASE_ID e INSTANCE_ID globais)
**Saída:** DDL completa do banco (todos os objetos)

**Implementação:**
```bash
get_full_database_ddl() {
  gcloud spanner databases ddl describe ${DATABASE_ID} \
    --instance=${INSTANCE_ID} 2>/dev/null
}
```

**Nota:** Esta função retorna TUDO do banco, não apenas uma tabela específica. Isso permite à LLM analisar:
- **Sequences compartilhadas:** Se uma sequence é usada em múltiplas tabelas, pode indicar padrão de design
- **Funções customizadas:** Funções usadas em DEFAULT podem afetar geração de keys
- **Índices relacionados:** Índices em outras tabelas que referenciam a tabela analisada
- **Contexto completo:** Entender o design geral do banco ajuda a identificar padrões problemáticos
- **Dependências:** Verificar se sequences/funções são compartilhadas entre tabelas

**Exemplo de uso:**
```bash
# Obter DDL completa
FULL_DDL=$(get_full_database_ddl)

# FULL_DDL contém:
# CREATE SEQUENCE seq_members START COUNTER WITH 1;
# CREATE TABLE members (... DEFAULT GET_NEXT_SEQUENCE_VALUE(seq_members));
# CREATE TABLE orders (... DEFAULT GET_NEXT_SEQUENCE_VALUE(seq_members));
# CREATE INDEX idx_members_user ON members(user_id);
# CREATE FUNCTION generate_id() RETURNS INT64 AS (SELECT ...);
```

---

### 2. Função: `get_table_metadata()`
**Localização:** Após `get_table_ddl()`

**Responsabilidade:**
- Obter metadados estruturados da tabela:
  - Primary Key (colunas, tipos, default values)
  - Índices secundários (nome, colunas, tipo)
  - Colunas (nome, tipo, nullable, default)
- Retornar JSON estruturado para facilitar análise

**Entrada:** `table_name`
**Saída:** JSON com metadados estruturados

**Estrutura JSON:**
```json
{
  "table_name": "members",
  "primary_key": {
    "columns": [
      {"name": "member_id", "type": "INT64", "default": "GET_NEXT_SEQUENCE_VALUE(...)"}
    ]
  },
  "indexes": [
    {"name": "idx_user", "type": "INDEX", "columns": ["user_id"]}
  ],
  "columns": [
    {"name": "member_id", "type": "INT64", "nullable": false, "default": "GET_NEXT_SEQUENCE_VALUE(...)"},
    {"name": "status", "type": "STRING(10)", "nullable": true}
  ]
}
```

---

### 3. Função: `build_hotspot_prompt()`
**Localização:** Após `get_table_metadata()`

**Responsabilidade:**
- Construir prompt estruturado para a LLM
- Incluir contexto sobre hotspots no Spanner
- Incluir DDL COMPLETA do banco (todos os objetos)
- Incluir metadados da tabela específica a ser analisada
- Definir formato de resposta esperado

**Entrada:** 
- `full_ddl` (string) - DDL completa do banco (tabelas, índices, sequences, funções)
- `table_name` (string) - Nome da tabela a ser analisada
- `metadata` (JSON string) - Metadados da tabela específica

**Saída:** Prompt completo para LLM

**Nota:** A DDL completa permite à LLM:
- Identificar sequences compartilhadas
- Verificar se sequences são usadas em outras tabelas
- Analisar funções customizadas usadas em defaults
- Entender contexto completo do banco

**Estrutura do Prompt:**
```
Você é um especialista em Google Cloud Spanner analisando hotspots.

CONTEXTO SOBRE HOTSPOTS:
1. Sequência explícita (DEFAULT GET_NEXT_SEQUENCE_VALUE(...)) → HOTSPOT QUASE CERTO
2. Timestamp como PK → HOTSPOT QUASE CERTO
3. INT64 sem randomização → Alto risco (80% dos casos viram hotspot)
4. STRING UUID → Seguro

DDL COMPLETA DO BANCO DE DADOS:
[DDL completa aqui - inclui TODAS as tabelas, índices, sequences e funções]

TABELA A ANALISAR: ${table_name}

METADADOS DA TABELA ESPECÍFICA:
[JSON metadata aqui - apenas da tabela sendo analisada]

IMPORTANTE:
- Analise a tabela "${table_name}" especificamente
- Considere o contexto completo do banco (sequences compartilhadas, etc)
- Verifique se sequences usadas na tabela são compartilhadas com outras tabelas
- Analise funções customizadas que possam afetar a geração de keys

Analise a tabela "${table_name}" e retorne JSON no formato:
{
  "table_name": "nome_tabela",
  "primary_key_analysis": {
    "columns": [{"name": "...", "type": "...", "default": "..."}],
    "classification": "HOTSPOT QUASE CERTO" | "Alto risco" | "Seguro",
    "risk_score": 0-100,
    "reason": "explicação"
  },
  "secondary_indexes": [
    {
      "name": "...",
      "risk": "..." | null,
      "reason": "..."
    }
  ],
  "column_risks": [
    {"column": "...", "risk": "...", "reason": "..."}
  ],
  "final_score": 0-100,
  "risk_level": "ALTO" | "MÉDIO" | "BAIXO",
  "recommendations": ["...", "..."]
}
```

---

### 4. Função: `call_openai_api()`
**Localização:** Após `build_hotspot_prompt()`

**Responsabilidade:**
- Fazer chamada HTTP para API da OpenAI
- Usar configuração LLM atual (provider, model, api_key)
- Tratar erros de API
- Retornar resposta JSON

**Entrada:**
- `prompt` (string)
- `model` (string, default: gpt-3.5-turbo)
- `api_key` (string)

**Saída:** JSON response da OpenAI

**Implementação:**
- Usar `curl` para fazer POST para `https://api.openai.com/v1/chat/completions`
- Headers: `Authorization: Bearer ${api_key}`, `Content-Type: application/json`
- Body: `{"model": "${model}", "messages": [{"role": "user", "content": "${prompt}"}], "temperature": 0.3, "response_format": {"type": "json_object"}}`
- Extrair `choices[0].message.content` da resposta

**Tratamento de Erros:**
- Verificar se `curl` está instalado
- Verificar se API key é válida
- Verificar rate limits
- Timeout de 30 segundos

---

### 5. Função: `format_hotspot_report()`
**Localização:** Após `call_openai_api()`

**Responsabilidade:**
- Processar resposta JSON da LLM
- Formatar saída similar ao exemplo fornecido
- Usar cores ANSI para destacar riscos
- Validar estrutura do JSON retornado

**Entrada:** JSON response da LLM
**Saída:** Texto formatado para exibição

**Formato de Saída:**
```
════════════════════════════════════════════
🔥 HOTSPOT ANALYSIS — TABLE: members
════════════════════════════════════════════

Primary Key:
- member_id (INT64)
- Default: SEQUENCE
❌ Classificação: HOTSPOT QUASE CERTO

Secondary Indexes:
- idx_user → Herda hotspot da PK
- idx_status → Hotspot por baixa cardinalidade

Column Risks:
- status → baixa cardinalidade
- type → baixa cardinalidade

Score Final: 92 / 100
Risk Level: 🔴 ALTO

✅ Recomendações:
- Substituir PK sequencial por UUID
- Usar hash(member_id) como prefixo
- Evitar índices sobre colunas categóricas
```

---

### 6. Comando `\hotspot-ai <table>`
**Localização:** Após comando `\llm` (após linha ~1721)

**Sintaxe:** `\hotspot-ai <table>` ou `\hotspot-ai <table> --verbose`

**Fluxo:**
1. Validar sintaxe do comando
2. Extrair nome da tabela
3. Validar se tabela existe
4. Verificar se LLM está configurada
5. Obter DDL COMPLETA do banco (todos os objetos)
6. Obter metadados da tabela específica
7. Construir prompt (incluir DDL completa + metadados da tabela)
8. Chamar API OpenAI
9. Processar resposta
10. Formatar e exibir relatório

**Validações:**
- Tabela deve existir
- LLM deve estar configurada
- `curl` deve estar instalado
- `jq` deve estar instalado (para processar JSON)

**Tratamento de Erros:**
- Tabela não encontrada
- LLM não configurada
- Erro na chamada da API
- Resposta inválida da LLM
- Timeout

---

## 📝 Detalhamento Técnico

### 1. Obtenção de DDL Completa
```bash
# Obter DDL COMPLETA do banco (todos os objetos)
# Usar comando existente \da internamente
FULL_DDL=$(gcloud spanner databases ddl describe ${DATABASE_ID} \
  --instance=${INSTANCE_ID} 2>/dev/null)

# Esta DDL inclui:
# - CREATE TABLE statements (todas as tabelas)
# - CREATE INDEX statements (todos os índices)
# - CREATE SEQUENCE statements (todas as sequences)
# - CREATE FUNCTION statements (todas as funções)
```

### 2. Obtenção de Default Values
```sql
SELECT 
  column_name,
  spanner_type,
  column_default
FROM information_schema.columns 
WHERE table_name = '${TABLE_NAME}'
ORDER BY ordinal_position;
```

**Nota:** `column_default` pode conter `GET_NEXT_SEQUENCE_VALUE(...)` para detectar sequências.

### 3. Chamada à API OpenAI
```bash
# Usar curl com JSON
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "https://api.openai.com/v1/chat/completions" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${MODEL}\",
    \"messages\": [{\"role\": \"user\", \"content\": \"${PROMPT}\"}],
    \"temperature\": 0.3,
    \"response_format\": {\"type\": \"json_object\"}
  }" \
  --max-time 30)

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

# Extrair conteúdo da resposta
CONTENT=$(echo "$BODY" | jq -r '.choices[0].message.content' 2>/dev/null)
```

### 4. Processamento de Resposta
```bash
# Validar JSON
if ! echo "$CONTENT" | jq . >/dev/null 2>&1; then
  echo "Erro: Resposta inválida da LLM"
  return 1
fi

# Extrair campos
TABLE_NAME=$(echo "$CONTENT" | jq -r '.table_name')
FINAL_SCORE=$(echo "$CONTENT" | jq -r '.final_score')
RISK_LEVEL=$(echo "$CONTENT" | jq -r '.risk_level')
# ... etc
```

---

## 🎨 Formatação de Saída

### Cores e Símbolos
- 🔴 ALTO risco: `RED`
- 🟡 MÉDIO risco: `YELLOW` (adicionar ao código)
- 🟢 BAIXO risco: `GREEN`
- ❌ Hotspot detectado: `RED`
- ✅ Seguro: `GREEN`
- ⚠️ Atenção: `YELLOW`

### Estrutura Visual
```
════════════════════════════════════════════  (linha dupla)
🔥 HOTSPOT ANALYSIS — TABLE: nome
════════════════════════════════════════════

Primary Key:
- coluna (tipo)
- Default: valor
[classificação]

Secondary Indexes:
- nome → motivo

Column Risks:
- coluna → motivo

Score Final: X / 100
Risk Level: [emoji] [nível]

✅ Recomendações:
- item 1
- item 2
```

---

## ✅ Checklist de Implementação

### Fase 1: Funções Auxiliares
- [ ] `get_full_database_ddl()` - Obter DDL completa do banco (todos os objetos)
- [ ] `get_table_metadata()` - Obter metadados estruturados da tabela específica
- [ ] `build_hotspot_prompt()` - Construir prompt para LLM (incluir DDL completa + metadados)
- [ ] `call_openai_api()` - Chamar API OpenAI
- [ ] `format_hotspot_report()` - Formatar relatório

### Fase 2: Comando Principal
- [ ] Implementar `\hotspot-ai <table>`
- [ ] Validações (tabela existe, LLM configurada, dependências)
- [ ] Tratamento de erros
- [ ] Integração com help (`\help`)

### Fase 3: Melhorias
- [ ] Adicionar cor YELLOW ao código
- [ ] Suporte a `--verbose` para mais detalhes
- [ ] Cache de resultados (opcional)
- [ ] Validação de resposta JSON da LLM
- [ ] Fallback se LLM retornar formato inválido

### Fase 4: Testes
- [ ] Testar com tabela com PK sequencial
- [ ] Testar com tabela com PK timestamp
- [ ] Testar com tabela com PK UUID
- [ ] Testar com tabela sem PK
- [ ] Testar sem LLM configurada
- [ ] Testar com erro de API

---

## 🔍 Dependências

### Ferramentas Necessárias
1. **curl** - Para chamadas HTTP à API OpenAI
2. **jq** - Para processar JSON (já usado no projeto)
3. **LLM configurada** - Via `--llm-setup`

### Verificações
```bash
# Verificar curl
if ! command -v curl >/dev/null 2>&1; then
  echo "❌ curl is not installed"
  return 1
fi

# Verificar jq (já existe no código)
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq is not installed"
  return 1
fi

# Verificar LLM configurada
CURRENT_KEY=$(get_current_llm_api_key)
if [[ -z "$CURRENT_KEY" ]]; then
  echo "❌ LLM not configured. Use: spanner-shell --llm-setup"
  return 1
fi
```

---

## 📊 Estrutura de Dados

### Prompt para LLM
```
Você é um especialista em Google Cloud Spanner analisando problemas de hotspot.

CONTEXTO:
Hotspots ocorrem quando muitas operações de escrita concentram-se em uma única partição.
Padrões que causam hotspots:
1. PRIMARY KEY sequencial (DEFAULT GET_NEXT_SEQUENCE_VALUE(...)) → HOTSPOT QUASE CERTO
2. PRIMARY KEY com TIMESTAMP → HOTSPOT QUASE CERTO  
3. PRIMARY KEY INT64 sem randomização → Alto risco (80% dos casos viram hotspot)
4. PRIMARY KEY STRING UUID → Seguro

DDL COMPLETA DO BANCO DE DADOS:
[DDL completa aqui - TODAS as tabelas, índices, sequences e funções]

TABELA A ANALISAR: ${table_name}

Analise especificamente a tabela "${table_name}" considerando o contexto completo do banco e retorne JSON estruturado com:
- Análise da Primary Key
- Análise de índices secundários
- Riscos por coluna
- Score final (0-100)
- Nível de risco (ALTO/MÉDIO/BAIXO)
- Recomendações específicas

Formato JSON obrigatório.
```

### Resposta Esperada da LLM
```json
{
  "table_name": "members",
  "primary_key_analysis": {
    "columns": [
      {
        "name": "member_id",
        "type": "INT64",
        "default": "GET_NEXT_SEQUENCE_VALUE(...)"
      }
    ],
    "classification": "HOTSPOT QUASE CERTO",
    "risk_score": 95,
    "reason": "PK usa sequência explícita que causa concentração de writes"
  },
  "secondary_indexes": [
    {
      "name": "idx_user",
      "risk": "Herda hotspot da PK",
      "reason": "Índice inclui coluna da PK sequencial"
    },
    {
      "name": "idx_status",
      "risk": "Hotspot por baixa cardinalidade",
      "reason": "Coluna status tem poucos valores distintos"
    }
  ],
  "column_risks": [
    {
      "column": "status",
      "risk": "baixa cardinalidade",
      "reason": "Coluna categórica com poucos valores"
    }
  ],
  "final_score": 92,
  "risk_level": "ALTO",
  "recommendations": [
    "Substituir PK sequencial por UUID",
    "Usar hash(member_id) como prefixo",
    "Evitar índices sobre colunas categóricas"
  ]
}
```

---

## 🚀 Ordem de Implementação

### Passo 1: Adicionar cor YELLOW
```bash
YELLOW='\033[0;33m'
```

### Passo 2: Função `get_full_database_ddl()`
- Reutilizar lógica do `\da` (DDL completa)
- Retornar DDL completa como string
- Incluir todos os objetos: tabelas, índices, sequences, funções

### Passo 3: Função `get_table_metadata()`
- Query para obter default values
- Montar JSON estruturado

### Passo 4: Função `build_hotspot_prompt()`
- Template do prompt
- Inserir DDL COMPLETA do banco (todos os objetos)
- Inserir metadados da tabela específica
- Especificar qual tabela deve ser analisada

### Passo 5: Função `call_openai_api()`
- Implementar chamada curl
- Tratamento de erros HTTP
- Extrair conteúdo da resposta

### Passo 6: Função `format_hotspot_report()`
- Processar JSON da resposta
- Formatar saída bonita
- Usar cores apropriadas

### Passo 7: Comando `\hotspot-ai`
- Integrar todas as funções
- Validações
- Tratamento de erros
- Adicionar ao help

---

## 🧪 Casos de Teste

### Teste 1: Tabela com PK Sequencial
```sql
CREATE TABLE test_seq (
  id INT64 NOT NULL DEFAULT (GET_NEXT_SEQUENCE_VALUE(SEQUENCE seq_test)),
  name STRING(255)
) PRIMARY KEY (id);
```
**Resultado esperado:** HOTSPOT QUASE CERTO, score alto

### Teste 2: Tabela com PK Timestamp
```sql
CREATE TABLE test_timestamp (
  created_at TIMESTAMP NOT NULL,
  data STRING(255)
) PRIMARY KEY (created_at);
```
**Resultado esperado:** HOTSPOT QUASE CERTO, score alto

### Teste 3: Tabela com PK UUID
```sql
CREATE TABLE test_uuid (
  id STRING(36) NOT NULL,
  name STRING(255)
) PRIMARY KEY (id);
```
**Resultado esperado:** Seguro, score baixo

### Teste 4: Tabela sem LLM configurada
**Resultado esperado:** Erro informando para configurar LLM

### Teste 5: Tabela inexistente
**Resultado esperado:** Erro informando tabela não encontrada

---

## 📚 Referências

### API OpenAI
- Endpoint: `https://api.openai.com/v1/chat/completions`
- Método: POST
- Headers: `Authorization: Bearer ${api_key}`, `Content-Type: application/json`
- Body: `{"model": "...", "messages": [...], "response_format": {"type": "json_object"}}`

### Documentação Spanner Hotspots
- [Spanner Hotspot Detection](https://cloud.google.com/spanner/docs/hotspot-detection)
- Padrões de PK que causam hotspots
- Boas práticas de design

---

## 🔄 Melhorias Futuras

1. **Cache de Resultados**
   - Salvar análises em arquivo temporário
   - Evitar re-análise da mesma tabela

2. **Análise de Múltiplas Tabelas**
   - `\hotspot-ai --all` para analisar todas as tabelas

3. **Exportar Relatório**
   - `\hotspot-ai <table> --export report.json`

4. **Suporte a Outros Providers**
   - Claude (Anthropic)
   - Gemini (Google)

5. **Análise Estatística**
   - Combinar análise LLM com dados reais de uso
   - Query para detectar distribuição de keys

---

## 📝 Notas de Implementação

### Considerações Importantes
1. **Timeout:** API pode demorar, usar timeout de 30s
2. **Rate Limits:** OpenAI tem limites, tratar erro 429
3. **Custos:** Cada chamada consome tokens, informar usuário
4. **Privacidade:** DDL pode conter informações sensíveis
5. **Validação:** Sempre validar JSON retornado pela LLM

### Tratamento de Erros Específicos
- **401 Unauthorized:** API key inválida
- **429 Too Many Requests:** Rate limit excedido
- **500 Internal Server Error:** Erro do servidor OpenAI
- **Timeout:** Chamada demorou mais de 30s
- **JSON inválido:** Resposta não é JSON válido
- **Campos faltando:** JSON não tem estrutura esperada

---

## ✅ Critérios de Sucesso

1. ✅ Comando `\hotspot-ai <table>` funciona corretamente
2. ✅ Identifica corretamente PK sequencial
3. ✅ Identifica corretamente PK timestamp
4. ✅ Identifica corretamente PK UUID como seguro
5. ✅ Formata saída similar ao exemplo fornecido
6. ✅ Trata erros de forma elegante
7. ✅ Integrado ao sistema de help
8. ✅ Documentado no README

---

**Data de Criação:** 2024
**Versão do Plano:** 1.0
