# Plano de Implementação: Comando `--list-profile`

## 📋 Objetivo
Implementar o comando `--list-profile` que lista todos os perfis disponíveis numerados e permite ao usuário selecionar um perfil interativamente.

## 🎯 Comportamento Esperado

### Fluxo de Execução:
1. Usuário executa: `spanner-shell --list-profile`
2. Script lista todos os perfis encontrados em `~/.spanner-shell/profiles/` numerados
3. Script pergunta: "Qual perfil deseja usar? (digite o número): "
4. Usuário digita o número e pressiona Enter
5. Script carrega o perfil selecionado e continua a execução normal

## 📝 Detalhamento Técnico

### 1. Localização no Código
- **Posição**: Após o comando `--config` e antes do comando `--profile`
- **Linha aproximada**: Entre as linhas 67-68 (após `exit 0` do `--config`)

### 2. Estrutura do Comando

```bash
if [[ "$1" == "--list-profile" ]]; then
  # Implementação aqui
fi
```

### 3. Lógica de Implementação

#### 3.1. Buscar Perfis
- Listar todos os arquivos `.env` no diretório `$PROFILE_DIR`
- Extrair o nome do perfil (remover extensão `.env`)
- Armazenar em um array

#### 3.2. Exibir Lista Numerada
- Verificar se existem perfis
- Se não houver perfis, exibir mensagem e sair
- Se houver perfis, exibir lista numerada (1, 2, 3, ...)
- Mostrar informações básicas de cada perfil (opcional: tipo, project_id)

#### 3.3. Solicitar Seleção
- Exibir prompt: "Qual perfil deseja usar? (digite o número): "
- Ler entrada do usuário
- Validar se o número é válido (dentro do range)
- Se inválido, exibir erro e sair

#### 3.4. Carregar Perfil Selecionado
- Obter nome do perfil baseado no número selecionado
- Carregar arquivo `.env` correspondente usando `source`
- Continuar execução normal (não fazer `exit`, apenas `source`)

### 4. Tratamento de Erros

#### 4.1. Nenhum Perfil Encontrado
```
❌ Nenhum perfil encontrado.
➡️  Crie um perfil com: spanner-shell --config
```

#### 4.2. Número Inválido
```
❌ Número inválido. Por favor, escolha um número entre 1 e X.
```

#### 4.3. Entrada Vazia
```
❌ Nenhum número foi informado.
```

### 5. Exemplo de Saída Esperada

```
📋 Perfis disponíveis:
   1) dev (remote) - projeto-dev
   2) stage (remote) - projeto-stage
   3) prod (remote) - projeto-prod
   4) local (emulator) - projeto-local

Qual perfil deseja usar? (digite o número): 2
✅ Perfil 'stage' carregado com sucesso!
```

## 🔧 Implementação Detalhada

### Passo 1: Estrutura Básica
```bash
if [[ "$1" == "--list-profile" ]]; then
  # Código aqui
fi
```

### Passo 2: Buscar Perfis
```bash
PROFILES=()
PROFILE_NAMES=()

# Buscar todos os arquivos .env
for profile_file in "$PROFILE_DIR"/*.env; do
  if [[ -f "$profile_file" ]]; then
    # Extrair nome do perfil (sem .env)
    profile_name=$(basename "$profile_file" .env)
    PROFILES+=("$profile_file")
    PROFILE_NAMES+=("$profile_name")
  fi
done
```

### Passo 3: Validar se há Perfis
```bash
if [[ ${#PROFILES[@]} -eq 0 ]]; then
  echo "❌ Nenhum perfil encontrado."
  echo "➡️  Crie um perfil com: spanner-shell --config"
  exit 1
fi
```

### Passo 4: Exibir Lista
```bash
echo "📋 Perfis disponíveis:"
for i in "${!PROFILE_NAMES[@]}"; do
  idx=$((i + 1))
  profile_name="${PROFILE_NAMES[$i]}"
  
  # Opcional: Carregar perfil temporariamente para mostrar info
  source "${PROFILES[$i]}" 2>/dev/null
  echo "   ${idx}) ${profile_name} (${TYPE}) - ${PROJECT_ID}"
done
```

### Passo 5: Solicitar e Validar Seleção
```bash
echo
read -p "Qual perfil deseja usar? (digite o número): " SELECTED_NUM

# Validar entrada
if [[ -z "$SELECTED_NUM" ]]; then
  echo "❌ Nenhum número foi informado."
  exit 1
fi

# Converter para número
if ! [[ "$SELECTED_NUM" =~ ^[0-9]+$ ]]; then
  echo "❌ Entrada inválida. Por favor, digite um número."
  exit 1
fi

# Validar range
if [[ "$SELECTED_NUM" -lt 1 || "$SELECTED_NUM" -gt ${#PROFILES[@]} ]]; then
  echo "❌ Número inválido. Por favor, escolha um número entre 1 e ${#PROFILES[@]}."
  exit 1
fi
```

### Passo 6: Carregar Perfil Selecionado
```bash
# Obter índice (subtrair 1 porque array começa em 0)
idx=$((SELECTED_NUM - 1))
SELECTED_PROFILE="${PROFILES[$idx]}"
SELECTED_NAME="${PROFILE_NAMES[$idx]}"

# Carregar perfil
source "$SELECTED_PROFILE"

echo "✅ Perfil '${SELECTED_NAME}' carregado com sucesso!"
echo
```

### Passo 7: Continuar Execução
- **NÃO fazer `exit`** após carregar o perfil
- O script deve continuar normalmente após o bloco `if`
- As variáveis `PROJECT_ID`, `INSTANCE_ID`, `DATABASE_ID`, `TYPE` estarão disponíveis

## ⚠️ Considerações Importais

### 1. Ordem de Verificação
- O comando `--list-profile` deve ser verificado **ANTES** do comando `--profile`
- Isso evita conflitos na interpretação dos argumentos

### 2. Não Fazer Exit Após Carregar
- Após carregar o perfil, **NÃO** fazer `exit 0`
- O script deve continuar para a validação de variáveis e execução normal

### 3. Limpar Variáveis Temporárias
- Após exibir a lista, pode ser necessário limpar variáveis temporárias
- Ou usar um escopo separado para evitar conflitos

### 4. Melhorias Futuras (Opcional)
- Mostrar informações adicionais (Project ID, Instance ID)
- Ordenar perfis alfabeticamente
- Permitir busca/filtro
- Mostrar perfil ativo (se houver)

## 📍 Localização Exata no Código

**Arquivo**: `spanner-shell.sh`
**Linha aproximada**: Após linha 67 (após `exit 0` do `--config`)
**Antes de**: Linha 69 (comando `--profile`)

## ✅ Checklist de Implementação

- [ ] Adicionar verificação do comando `--list-profile`
- [ ] Implementar busca de perfis no diretório
- [ ] Implementar exibição numerada
- [ ] Implementar validação de entrada
- [ ] Implementar carregamento do perfil selecionado
- [ ] Adicionar tratamento de erros
- [ ] Testar com múltiplos perfis
- [ ] Testar com nenhum perfil
- [ ] Testar com entrada inválida
- [ ] Atualizar documentação (README.md)
- [ ] Atualizar comando `\help` (se aplicável)

## 🧪 Casos de Teste

### Teste 1: Listar Perfis Existentes
```bash
spanner-shell --list-profile
# Deve listar todos os perfis e permitir seleção
```

### Teste 2: Nenhum Perfil
```bash
# Remover todos os perfis
rm ~/.spanner-shell/profiles/*.env
spanner-shell --list-profile
# Deve exibir mensagem de erro
```

### Teste 3: Entrada Inválida
```bash
spanner-shell --list-profile
# Digitar "abc" ou número fora do range
# Deve exibir mensagem de erro
```

### Teste 4: Seleção Válida
```bash
spanner-shell --list-profile
# Digitar número válido
# Deve carregar perfil e continuar execução
```

## 📚 Atualizações de Documentação

### README.md
- Adicionar seção sobre `--list-profile` na seção de comandos de configuração
- Adicionar exemplo de uso
- Atualizar seção de configuração inicial

### Comando `\help` (se aplicável)
- Não necessário, pois é comando de linha de comando, não do shell interativo
