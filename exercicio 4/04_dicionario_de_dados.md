# Dicionario de dados — criacao de manutencao

Escopo: tabelas usadas pelo fluxo de criacao de manutencao. Os tipos e nomes correspondem a `exercicio 1\01_ddl_criacao_tabelas.sql`. O arquivo SQL e a referencia final para constraints e valores de `ENUM`.

## `usuarios`

| Campo | Tipo | Obrigatorio | Chave / regra | Descricao |
|---|---|---:|---|---|
| `id_usuario` | `INT` | Sim | PK, auto incremento | Identificador do usuario. |
| `nome` | `VARCHAR(100)` | Sim | — | Nome exibido do usuario. |
| `email` | `VARCHAR(150)` | Sim | UNIQUE | E-mail de acesso. |
| `cargo` | `ENUM` | Sim | Valores definidos no DDL | Perfil de acesso; a criacao da manutencao exige `suporte` ativo. |
| `senha_hash` | `VARCHAR(255)` | Sim | — | Hash de senha; nunca armazenar senha em texto puro. |
| `ativo` | `BOOLEAN` | Sim | DEFAULT `TRUE` | Indica se o usuario pode operar. |

## `projetos`

| Campo | Tipo | Obrigatorio | Chave / regra | Descricao |
|---|---|---:|---|---|
| `projeto_id` | `INT` | Sim | PK, auto incremento | Identificador do projeto. |
| `nome` | `VARCHAR(150)` | Sim | — | Nome do projeto relacionado. |
| `responsavel_id` | `INT` | Nao | FK → `usuarios.id_usuario`; ON DELETE SET NULL, ON UPDATE RESTRICT | Responsavel geral do projeto. |
| `vendedor_id` | `INT` | Nao | FK → `usuarios.id_usuario`; ON DELETE SET NULL, ON UPDATE RESTRICT | Vendedor associado ao projeto. |

## `manutencoes`

| Campo | Tipo | Obrigatorio | Chave / regra | Descricao |
|---|---|---:|---|---|
| `manutencao_id` | `INT` | Sim | PK, auto incremento | Identificador da manutencao. |
| `data_inicio_problema` | `DATE` | Sim | — | Data de inicio do problema. |
| `tipo_manutencao` | `ENUM` | Sim | `corretiva`, `preventiva`, `evolutiva`, `adaptativa` | Classificacao da manutencao. |
| `descricao_situacao` | `TEXT` | Sim | CHECK: de 1 a 5000 caracteres apos `TRIM` | Descricao do problema informado. |
| `status` | `ENUM` | Sim | DEFAULT `aberta`; `aberta`, `em andamento`, `concluida`, `cancelada` | Situacao persistida. A procedure converte `em_andamento` recebido pela API para `em andamento`. |
| `data_criacao` | `DATETIME` | Sim | DEFAULT `CURRENT_TIMESTAMP` | Data e hora de inclusao no banco. |
| `projeto_id` | `INT` | Nao | FK → `projetos.projeto_id`; ON DELETE SET NULL, ON UPDATE RESTRICT | Projeto opcional associado. |
| `resumo` | `VARCHAR(255)` | Nao no DDL | CHECK de 1 a 255 caracteres se informado; trigger exige valor na inclusao | Resumo curto da manutencao. |
| `responsavel_id` | `INT` | Nao no DDL | FK → `usuarios.id_usuario`; ON DELETE SET NULL, ON UPDATE RESTRICT; trigger exige usuario suporte ativo ao inserir | Usuario responsavel pela manutencao. |
| `data_limite` | `DATE` | Nao no DDL | —; procedure exige valor ao criar | Prazo previsto para a manutencao. |
| `prioridade` | `ENUM` | Sim | DEFAULT `media`; `baixa`, `media`, `alta`, `critica` | Prioridade operacional. |

## `anexo`

| Campo | Tipo | Obrigatorio | Chave / regra | Descricao |
|---|---|---:|---|---|
| `anexo_id` | `INT` | Sim | PK, auto incremento | Identificador do anexo. |
| `os_id` | `INT` | Nao | Deve permanecer NULL neste recorte | Campo preservado do modelo da API; o fluxo documentado nao anexa arquivo a uma OS. |
| `nome_anexo` | `VARCHAR(255)` | Sim | — | Nome original do arquivo. |
| `anexo_tipo` | `VARCHAR(150)` | Sim | — | Tipo MIME do arquivo. |
| `anexo_tamanho` | `BIGINT UNSIGNED` | Nao | Trigger define o tamanho real em bytes | Tamanho do conteudo binario. |
| `data_anexo` | `DATETIME` | Sim | DEFAULT `CURRENT_TIMESTAMP` | Data e hora de envio. |
| `id_usuario_envio` | `INT` | Nao | FK → `usuarios.id_usuario`; ON DELETE SET NULL, ON UPDATE RESTRICT | Usuario que enviou o arquivo. |
| `manutencao_id` | `INT` | Nao no DDL | FK → `manutencoes.manutencao_id`; ON DELETE CASCADE, ON UPDATE RESTRICT; CHECK e trigger exigem o vinculo no recorte | Manutencao a que o anexo pertence. |
| `projeto_id` | `INT` | Nao | FK → `projetos.projeto_id`; ON DELETE CASCADE, ON UPDATE RESTRICT; deve ser NULL neste recorte | Campo preservado do modelo da API; nao usado como vinculo do anexo neste fluxo. |
| `conteudo_arquivo` | `LONGBLOB` | Sim | — | Conteudo binario do arquivo. |

## Relacionamentos e integridade referencial

- Um usuario pode ser responsavel por varias manutencoes; a manutencao pode ficar sem responsavel apos exclusao do usuario (`ON DELETE SET NULL`).
- Um projeto pode estar relacionado a varias manutencoes; a manutencao pode ficar sem projeto apos exclusao do projeto (`ON DELETE SET NULL`).
- Uma manutencao pode ter varios anexos; a exclusao da manutencao remove seus anexos (`ON DELETE CASCADE`).
- Um usuario pode enviar varios anexos; a exclusao do usuario preserva o anexo e limpa `id_usuario_envio` (`ON DELETE SET NULL`).
- Atualizacoes de identificadores referenciados sao restringidas (`ON UPDATE RESTRICT`).
