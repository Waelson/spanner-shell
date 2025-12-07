# Spanner Shell

Uma ferramenta CLI interativa e intuitiva para trabalhar com Google Cloud Spanner, oferecendo uma experiência similar ao `psql` (PostgreSQL) ou `mysql` (MySQL), mas otimizada para o ecossistema Spanner.

## 📋 Índice

- [Sobre o Projeto](#sobre-o-projeto)
- [Problemas que Resolve](#problemas-que-resolve)
- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Configuração Inicial](#configuração-inicial)
- [Comandos Disponíveis](#comandos-disponíveis)
- [Atualização](#atualização)
- [Desinstalação](#desinstalação)
- [Exemplos de Uso](#exemplos-de-uso)

---

## 🎯 Sobre o Projeto

O **Spanner Shell** é um shell interativo desenvolvido em Bash que simplifica o trabalho com bancos de dados Google Cloud Spanner. A ferramenta oferece uma interface de linha de comando amigável, permitindo executar queries SQL, gerenciar tabelas, visualizar dados e muito mais, tanto em ambientes de produção quanto no emulador local.

### Características Principais

- ✅ **Interface Interativa**: Prompt intuitivo similar a ferramentas SQL tradicionais
- ✅ **Suporte a Perfis**: Gerencie múltiplos ambientes (dev, stage, prod) facilmente
- ✅ **Emulador e Remoto**: Funciona tanto com o Spanner Emulator quanto com instâncias remotas
- ✅ **Histórico Isolado**: Histórico de comandos dedicado para o Spanner Shell
- ✅ **Comandos Especiais**: Atalhos para operações comuns (listar tabelas, descrever esquemas, etc.)
- ✅ **Geração de DML**: Gera automaticamente exemplos de INSERT, UPDATE, SELECT e DELETE
- ✅ **Monitoramento em Tempo Real**: Acompanhe novos registros em tabelas com `\tail -f`

---

## 💡 Problemas que Resolve

### 1. **Complexidade de Comandos gcloud**

O Google Cloud SDK (`gcloud`) requer comandos verbosos e complexos para executar queries SQL no Spanner. O Spanner Shell abstrai essa complexidade, permitindo que você execute queries SQL diretamente em um ambiente interativo.

**Antes:**
```bash
gcloud spanner databases execute-sql my-database \
  --instance=my-instance \
  --sql="SELECT * FROM users LIMIT 10;"
```

**Depois:**
```sql
spanner> SELECT * FROM users LIMIT 10;
```

### 2. **Falta de Interface Interativa**

Trabalhar com Spanner via `gcloud` é baseado em comandos únicos, sem um ambiente interativo. O Spanner Shell oferece um prompt contínuo onde você pode executar múltiplas queries, explorar o banco de dados e manter contexto.

### 3. **Gerenciamento de Múltiplos Ambientes**

Alternar entre diferentes projetos, instâncias e bancos de dados requer reconfigurar variáveis de ambiente ou executar comandos longos repetidamente. O Spanner Shell resolve isso com um sistema de perfis que permite alternar rapidamente entre ambientes.

### 4. **Exploração de Esquemas**

Descobrir a estrutura de tabelas, colunas e relacionamentos no Spanner pode ser trabalhoso. O Spanner Shell oferece comandos simples como `\dt` (listar tabelas) e `\d <tabela>` (descrever tabela) para facilitar a exploração.

### 5. **Geração de Código DML**

Criar queries INSERT, UPDATE, SELECT e DELETE manualmente pode ser tedioso e propenso a erros. O comando `\generate` analisa a estrutura da tabela e gera automaticamente exemplos de DML com tipos de dados corretos.

### 6. **Monitoramento de Dados**

Acompanhar novos registros inseridos em tabelas requer executar queries repetidamente. O comando `\tail -f` monitora automaticamente novas inserções, atualizando a cada 5 segundos.

---

## 📦 Pré-requisitos

### 1. **Google Cloud SDK (gcloud)**

O Spanner Shell utiliza o `gcloud` CLI para se comunicar com o Spanner. Você precisa ter o Google Cloud SDK instalado e configurado.

**Instalação no macOS:**
```bash
brew install --cask google-cloud-sdk
```

**Verificação:**
```bash
gcloud --version
```

### 2. **Autenticação (para Spanner Remoto)**

Se você planeja usar o Spanner Shell com instâncias remotas (não emulador), é necessário autenticar-se:

```bash
gcloud auth login
```

Para desenvolvimento local com o emulador, a autenticação não é necessária.

### 3. **Spanner Emulator (Opcional)**

Para desenvolvimento local, você pode usar o Spanner Emulator. O emulador deve estar rodando na porta padrão `9020`:

```bash
# Inicie o emulador (se estiver usando Docker)
docker run -d -p 9020:9020 -p 9010:9010 gcr.io/cloud-spanner-emulator/emulator
```

### 4. **Bash 4.0+**

O script requer Bash moderno. A maioria dos sistemas Unix-like (macOS, Linux) já possui Bash instalado.

**Verificação:**
```bash
bash --version
```

### 5. **Permissões de Escrita**

O Spanner Shell cria arquivos de configuração e histórico em `~/.spanner-shell/`. Certifique-se de ter permissões de escrita no diretório home.

---

## 🚀 Instalação

### Método 1: Instalação Automática (Recomendado)

1. **Clone o repositório:**
```bash
git clone https://github.com/Waelson/spanner-shell.git
cd spanner-shell
```

2. **Execute o script de instalação:**
```bash
./install.sh
```

O instalador irá:
- Copiar o script para `/opt/homebrew/bin` (macOS com Homebrew) ou `/usr/local/bin`
- Tornar o script executável
- Oferecer criar um alias `spanner` (opcional)

3. **Recarregue seu shell:**
```bash
source ~/.zshrc  # ou ~/.bashrc
```

4. **Verifique a instalação:**
```bash
spanner-shell --version
```

### Método 2: Instalação Manual

1. **Copie o script para um diretório no PATH:**
```bash
sudo cp spanner-shell.sh /usr/local/bin/spanner-shell
sudo chmod +x /usr/local/bin/spanner-shell
```

2. **Crie um alias (opcional):**
```bash
echo "alias spanner='spanner-shell'" >> ~/.zshrc
source ~/.zshrc
```

---

## ⚙️ Configuração Inicial

Antes de usar o Spanner Shell, você precisa criar um perfil de configuração. Um perfil armazena as informações de conexão (Project ID, Instance ID, Database ID) e o tipo de conexão (emulator ou remote).

### Criando um Perfil

Execute o comando de configuração:

```bash
spanner-shell --config
```

O assistente irá solicitar:
- **Nome do perfil**: Um identificador para o perfil (ex: `dev`, `stage`, `prod`)
- **Tipo**: `emulator` (para desenvolvimento local) ou `remote` (para produção)
- **Project ID**: ID do projeto Google Cloud
- **Instance ID**: ID da instância Spanner
- **Database ID**: ID do banco de dados Spanner

**Exemplo:**
```
Nome do perfil (ex: dev, stage, prod): dev
Tipo (emulator | remote): emulator
Project ID: my-project
Instance ID: test-instance
Database ID: my-database
```

### Usando um Perfil

Após criar um perfil, você pode iniciar o Spanner Shell com ele:

```bash
spanner-shell --profile dev
```

O perfil será carregado automaticamente e você entrará no shell interativo.

---

## 📚 Comandos Disponíveis

### Comandos de Configuração

#### `--version` ou `-v`
Exibe a versão do Spanner Shell.

```bash
spanner-shell --version
```

#### `--config`
Inicia o assistente interativo para criar um novo perfil de configuração.

```bash
spanner-shell --config
```

#### `--profile <nome>`
Inicia o Spanner Shell usando um perfil específico.

```bash
spanner-shell --profile dev
```

---

### Comandos Especiais (dentro do shell)

Todos os comandos especiais começam com `\` (barra invertida) e são executados dentro do shell interativo.

#### `\help` ou `\h`
Exibe a lista de todos os comandos disponíveis com suas descrições.

```sql
spanner> \help
```

#### `\config`
Exibe as configurações atuais do perfil carregado (tipo, projeto, instância, banco de dados).

```sql
spanner> \config
```

#### `\dt`
Lista todas as tabelas do banco de dados atual.

```sql
spanner> \dt
```

**Saída:**
```
table_name
----------
users
orders
products
```

#### `\d <tabela>`
Descreve a estrutura de uma tabela específica, mostrando colunas, tipos de dados e se são nullable.

```sql
spanner> \d users
```

**Saída:**
```
column_name  spanner_type    is_nullable
-----------  --------------  -----------
user_id      INT64           NO
name         STRING(255)     NO
email        STRING(255)     YES
created_at   TIMESTAMP       NO
```

#### `\count <tabela>`
Conta o número total de registros em uma tabela.

```sql
spanner> \count users
```

**Saída:**
```
Contando registros na tabela 'users'...
total
-----
1250
```

#### `\sample <tabela> [n]`
Mostra uma amostra de registros de uma tabela. Por padrão, exibe 10 registros. Você pode especificar um número diferente (máximo 1000).

```sql
spanner> \sample users
spanner> \sample users 20
```

**Saída:**
```
Mostrando 10 registros da tabela 'users':
----------------------------------------
user_id  name           email
-------  -------------  -------------------
1        João Silva     joao@example.com
2        Maria Santos   maria@example.com
...
```

#### `\tail <tabela> [n] [coluna]`
Mostra os últimos N registros de uma tabela, ordenados por uma coluna específica (ou pela chave primária, se não especificada). Por padrão, mostra 10 registros.

```sql
spanner> \tail users
spanner> \tail users 20
spanner> \tail users 15 created_at
```

**Parâmetros:**
- `<tabela>`: Nome da tabela (obrigatório)
- `[n]`: Número de registros a exibir (padrão: 10, máximo: 1000)
- `[coluna]`: Coluna para ordenação (padrão: chave primária ou primeira coluna)

#### `\tail -f <tabela> [n] [coluna]`
Monitora novos registros em uma tabela em tempo real, atualizando a cada 5 segundos. Similar ao `tail -f` do Unix.

```sql
spanner> \tail -f users
spanner> \tail -f orders 20 order_id
```

**Características:**
- Exibe apenas novos registros desde a última verificação
- Atualiza automaticamente a cada 5 segundos
- Pressione `Ctrl+C` para parar o monitoramento
- Ordena por chave primária ou coluna especificada

#### `\generate <tabela>`
Gera automaticamente exemplos de comandos DML (INSERT, UPDATE, SELECT, DELETE) baseados na estrutura da tabela.

```sql
spanner> \generate users
```

**Saída:**
```
📝 DML de exemplo para tabela: users
==========================================
-- INSERT
INSERT INTO users (
  user_id, name, email, created_at
) VALUES (
  123, 'exemplo', 'exemplo', CURRENT_TIMESTAMP()
);

-- SELECT
SELECT * FROM users
WHERE 
  user_id = 123;

-- UPDATE
UPDATE users
SET 
  name = 'exemplo', email = 'exemplo'
WHERE 
  user_id = 123;

-- DELETE
DELETE FROM users
WHERE 
  user_id = 123;
```

#### `\ddl <tabela>`
Exibe o DDL (Data Definition Language) de uma tabela específica, incluindo a definição CREATE TABLE e índices relacionados.

```sql
spanner> \ddl users
```

**Saída:**
```
CREATE TABLE users (
  user_id INT64 NOT NULL,
  name STRING(255) NOT NULL,
  email STRING(255),
  created_at TIMESTAMP NOT NULL,
) PRIMARY KEY (user_id);
```

#### `\ddl all`
Exibe o DDL completo de todo o banco de dados, incluindo todas as tabelas e índices.

```sql
spanner> \ddl all
```

#### `\import <arquivo.sql>`
Importa e executa um arquivo SQL contendo instruções DML (INSERT, UPDATE, DELETE, SELECT).

```sql
spanner> \import /caminho/para/arquivo.sql
```

**Características:**
- Executa todas as instruções SQL do arquivo
- Útil para importar dados ou executar scripts de migração
- Mostra mensagem de sucesso ou erro após a execução

**Exemplo de arquivo:**
```sql
-- arquivo.sql
INSERT INTO users (user_id, name, email) VALUES (1, 'João', 'joao@example.com');
INSERT INTO users (user_id, name, email) VALUES (2, 'Maria', 'maria@example.com');
```

#### `\import-ddl <arquivo.sql>`
Importa e executa um arquivo SQL contendo instruções DDL (CREATE TABLE, CREATE INDEX, ALTER TABLE, etc.).

```sql
spanner> \import-ddl /caminho/para/schema.sql
```

**Características:**
- Atualiza o esquema do banco de dados
- Útil para criar ou modificar estruturas de tabelas
- Requer permissões adequadas no Spanner

**Exemplo de arquivo:**
```sql
-- schema.sql
CREATE TABLE products (
  product_id INT64 NOT NULL,
  name STRING(255) NOT NULL,
  price FLOAT64 NOT NULL,
) PRIMARY KEY (product_id);

CREATE INDEX idx_products_name ON products(name);
```

#### `\repeat <n> <comando>`
Executa um comando SQL N vezes. Útil para testes de carga, inserções em lote ou operações repetitivas.

```sql
spanner> \repeat 5 SELECT COUNT(*) FROM users;
spanner> \repeat 10 INSERT INTO logs (message) VALUES ('test');
```

**Parâmetros:**
- `<n>`: Número de repetições (mínimo: 1, máximo: 100)
- `<comando>`: Comando SQL a ser executado

**Características:**
- Mostra o progresso de cada execução
- Exibe resultados de cada iteração
- Para em caso de erro (mas não interrompe execuções anteriores)

#### `\history [n]`
Exibe os últimos N comandos executados no histórico. Por padrão, mostra os últimos 20 comandos.

```sql
spanner> \history
spanner> \history 50
```

**Características:**
- Histórico isolado do Spanner Shell (não mistura com histórico do terminal)
- Filtra automaticamente comandos inválidos e comentários
- Útil para revisar comandos anteriores ou copiar queries

#### `\history clear`
Limpa todo o histórico de comandos do Spanner Shell.

```sql
spanner> \history clear
```

---

### Comandos de Sistema

#### `clear`
Limpa a tela do terminal, similar ao comando `clear` do Unix.

```sql
spanner> clear
```

#### `exit`
Encerra o Spanner Shell e retorna ao terminal.

```sql
spanner> exit
```

---

### Execução de SQL Direto

Além dos comandos especiais, você pode executar qualquer query SQL válida do Spanner diretamente:

```sql
spanner> SELECT * FROM users WHERE user_id = 1;

spanner> INSERT INTO users (user_id, name, email) 
    ... VALUES (100, 'João', 'joao@example.com');

spanner> UPDATE users SET email = 'novo@example.com' 
    ... WHERE user_id = 100;
```

**Características:**
- Suporte a queries multi-linha (continue digitando após pressionar Enter)
- Termine a query com `;` (ponto e vírgula) para executar
- Histórico de comandos com navegação usando setas do teclado
- Mensagens de erro claras e informativas

---

## 🔄 Atualização

Para atualizar o Spanner Shell para a versão mais recente:

```bash
./update.sh
```

O script de atualização:
1. Detecta onde o Spanner Shell está instalado
2. Clona a versão mais recente do repositório Git
3. Substitui o binário antigo pelo novo
4. Exibe a versão atualizada

**Nota:** O script de atualização requer que o Git esteja instalado.

---

## 🗑️ Desinstalação

Para remover o Spanner Shell do sistema:

```bash
./uninstall.sh
```

O script de desinstalação:
1. Remove o binário do sistema
2. Remove o alias `spanner` do arquivo de configuração do shell (se existir)
3. **Não remove** os perfis e histórico em `~/.spanner-shell/` (você pode removê-los manualmente se desejar)

---

## 💻 Exemplos de Uso

### Exemplo 1: Exploração Inicial de um Banco de Dados

```sql
spanner> \dt                    # Lista todas as tabelas
spanner> \d users               # Descreve a tabela users
spanner> \count users           # Conta registros
spanner> \sample users 5        # Mostra 5 exemplos
spanner> \tail users 10         # Mostra últimos 10 registros
```

### Exemplo 2: Geração de Código DML

```sql
spanner> \generate orders       # Gera exemplos de INSERT, UPDATE, etc.
# Copie e cole os exemplos gerados, ajustando os valores conforme necessário
```

### Exemplo 3: Monitoramento em Tempo Real

```sql
spanner> \tail -f logs          # Monitora novos logs em tempo real
# Pressione Ctrl+C para parar
```

### Exemplo 4: Importação de Dados

```sql
spanner> \import /path/to/data.sql
```

### Exemplo 5: Execução Repetida

```sql
spanner> \repeat 100 SELECT COUNT(*) FROM users;
```

### Exemplo 6: Trabalhando com Múltiplos Perfis

```bash
# Criar perfis para diferentes ambientes
spanner-shell --config  # Cria perfil 'dev'
spanner-shell --config  # Cria perfil 'prod'

# Alternar entre ambientes
spanner-shell --profile dev   # Ambiente de desenvolvimento
spanner-shell --profile prod  # Ambiente de produção
```

---

## 🐛 Solução de Problemas

### Erro: "gcloud não está instalado"

**Solução:** Instale o Google Cloud SDK:
```bash
brew install --cask google-cloud-sdk
```

### Erro: "Nenhuma autenticação ativa encontrada"

**Solução:** Autentique-se no gcloud:
```bash
gcloud auth login
```

### Erro: "Perfil não encontrado"

**Solução:** Crie um perfil primeiro:
```bash
spanner-shell --config
```

### Erro ao conectar com o Emulador

**Solução:** Certifique-se de que o emulador está rodando:
```bash
docker ps  # Verifique se o container está ativo
# Se não estiver, inicie o emulador
docker run -d -p 9020:9020 -p 9010:9010 gcr.io/cloud-spanner-emulator/emulator
```

### Histórico não está funcionando

**Solução:** Verifique as permissões do diretório:
```bash
ls -la ~/.spanner-shell/
chmod -R 755 ~/.spanner-shell/
```

---

## 📝 Notas Adicionais

- Os perfis são armazenados em `~/.spanner-shell/profiles/`
- O histórico é armazenado em `~/.spanner-shell/history`
- O Spanner Shell funciona tanto com Spanner remoto quanto com o emulador local
- Queries SQL são executadas através do `gcloud spanner databases execute-sql`
- O histórico é isolado e não interfere com o histórico do seu terminal

---

## 📄 Licença

Este projeto está sob a licença especificada no arquivo `LICENSE`.

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Sinta-se à vontade para abrir issues ou pull requests.

---

## 📧 Suporte

Para questões, sugestões ou problemas, abra uma issue no repositório do projeto.

---

**Versão:** 1.0.2
