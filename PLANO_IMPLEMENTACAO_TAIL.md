# Plano de Implementação: Comando `\tail`

## Objetivo
Implementar o comando `\tail` para exibir os últimos N registros de uma tabela, similar ao comando `tail` do Unix, com suporte a monitoramento contínuo.

## Especificações

### 1. Comando Básico: `\tail <tabela> [n] [coluna]`
- **Sintaxe**: `\tail <tabela> [n] [coluna]`
- **Parâmetros**:
  - `<tabela>`: Nome da tabela (obrigatório)
  - `[n]`: Número de registros a exibir (opcional, padrão: 10)
  - `[coluna]`: Coluna para ordenação (opcional, padrão: chave primária ou primeira coluna)
- **Funcionalidade**:
  - Executa uma consulta única
  - Ordena os registros pela coluna especificada em ordem decrescente
  - Limita o resultado a N registros
  - Exibe os resultados formatados

### 2. Comando com Follow: `\tail -f <tabela> [n] [coluna]`
- **Sintaxe**: `\tail -f <tabela> [n] [coluna]`
- **Parâmetros**: Mesmos do comando básico
- **Funcionalidade**:
  - Executa consultas periódicas a cada 5 segundos
  - Mostra apenas registros novos desde a última execução
  - Permite interrupção com Ctrl+C
  - Mantém o histórico dos últimos valores vistos para detectar novos registros

## Estrutura de Implementação

### Funções Auxiliares Necessárias

#### 1. `get_table_primary_key(table_name)`
- **Objetivo**: Obter a chave primária de uma tabela
- **Retorno**: Nome da primeira coluna da chave primária ou vazio se não houver
- **Implementação**: Query no `information_schema.index_columns`

#### 2. `get_table_first_column(table_name)`
- **Objetivo**: Obter a primeira coluna de uma tabela
- **Retorno**: Nome da primeira coluna
- **Implementação**: Query no `information_schema.columns`

#### 3. `validate_column_exists(table_name, column_name)`
- **Objetivo**: Validar se uma coluna existe na tabela
- **Retorno**: true/false
- **Implementação**: Query no `information_schema.columns`

#### 4. `get_default_order_column(table_name)`
- **Objetivo**: Determinar a coluna padrão para ordenação
- **Lógica**:
  1. Tenta obter chave primária
  2. Se não houver, usa primeira coluna
- **Retorno**: Nome da coluna

### Lógica Principal

#### Comando Básico `\tail <tabela> [n] [coluna]`
```
1. Validar sintaxe e extrair parâmetros
2. Validar se tabela existe
3. Determinar coluna de ordenação:
   - Se [coluna] especificada: validar se existe
   - Se não: usar get_default_order_column()
4. Determinar N (padrão: 10, validar: 1-1000)
5. Executar SQL: SELECT * FROM tabela ORDER BY coluna DESC LIMIT n
6. Exibir resultados formatados
7. Salvar no histórico
```

#### Comando com Follow `\tail -f <tabela> [n] [coluna]`
```
1. Validar sintaxe e extrair parâmetros (mesmo do básico)
2. Validar se tabela existe
3. Determinar coluna de ordenação
4. Determinar N
5. Loop infinito:
   a. Executar consulta
   b. Comparar com última execução (usar hash ou valores da coluna de ordenação)
   c. Exibir apenas registros novos
   d. Aguardar 5 segundos
   e. Verificar se Ctrl+C foi pressionado (trap SIGINT)
6. Ao sair: restaurar estado normal
```

## Detalhes Técnicos

### Regex para Parsing
- Básico: `^\\tail[[:space:]]+([a-zA-Z0-9_]+)([[:space:]]+([0-9]+))?([[:space:]]+([a-zA-Z0-9_]+))?$`
- Com -f: `^\\tail[[:space:]]+-f[[:space:]]+([a-zA-Z0-9_]+)([[:space:]]+([0-9]+))?([[:space:]]+([a-zA-Z0-9_]+))?$`

### Tratamento de Erros
- Tabela não encontrada
- Coluna não encontrada
- N inválido (fora do range 1-1000)
- Erros de SQL do Spanner

### Detecção de Novos Registros (modo -f)
- **Estratégia 1**: Comparar hash dos resultados
- **Estratégia 2**: Armazenar último valor da coluna de ordenação e buscar apenas registros maiores
- **Recomendação**: Estratégia 2 (mais eficiente)

### Interrupção do Follow Mode
- Usar `trap` para capturar SIGINT (Ctrl+C)
- Limpar estado e retornar ao loop principal

## Ordem de Implementação

1. ✅ Criar plano de implementação
2. Adicionar documentação no `\help`
3. Implementar funções auxiliares
4. Implementar comando básico `\tail`
5. Implementar comando com follow `\tail -f`
6. Testar ambos os comandos
7. Validar tratamento de erros

## Exemplos de Uso

```bash
# Últimos 10 registros ordenados por chave primária
\tail usuarios

# Últimos 20 registros ordenados por chave primária
\tail usuarios 20

# Últimos 10 registros ordenados por created_at
\tail usuarios 10 created_at

# Monitoramento contínuo (a cada 5s)
\tail -f usuarios

# Monitoramento contínuo com 20 registros ordenados por timestamp
\tail -f usuarios 20 timestamp
```

## Validações Necessárias

- [ ] Tabela existe
- [ ] Coluna existe (se especificada)
- [ ] N está entre 1 e 1000
- [ ] Coluna de ordenação é válida para ORDER BY
- [ ] Tratamento de erros do gcloud/spanner
- [ ] Interrupção limpa do modo -f

## Considerações

- O modo `-f` pode ser custoso em termos de recursos
- Limitar o número máximo de execuções ou adicionar timeout
- Considerar cache de metadados da tabela para melhor performance
- Adicionar feedback visual durante o modo follow (ex: indicador de atualização)
