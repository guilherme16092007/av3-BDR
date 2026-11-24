# Avaliacao de Banco de Dados Relacional — API

## Escopo

O trabalho modela somente a criacao de manutencao da API `API2_DSM_SprintingCheetahs`. A rota correspondente e `POST /api/manutencoes`, restrita ao perfil `suporte`. O recorte mantem os dados do usuario responsavel, o vinculo opcional com projeto e os anexos enviados com a manutencao.

Notificacoes, historico, OS, equipes e demais fluxos foram excluidos por nao serem dependencias necessarias para esta funcionalidade. O DDL e uma base de avaliacao e nao substitui o script integral de producao da API.

## Arquivos da entrega

1. [Modelo conceitual e logico](parte1_modelos_conceitual_logico.md)
2. [DDL — criacao das tabelas](exercicio%201/01_ddl_criacao_tabelas.sql)
3. [DML — insercao de dados](exercicio%202/02_dml_insercao_dados.sql)
4. [Programacao MySQL — view, 6 functions, 6 procedures e 6 triggers](exercicio%203/03_programacao_bd.sql)
5. [Dicionario de dados](exercicio%204/04_dicionario_de_dados.md)
6. [Integracao TypeScript com o banco](exercicio%205/backend/src/05_integracao_api.ts)

## Parte 1 — modelos

### Modelo conceitual

Entidades e identificadores:

- **USUARIO** (`id_usuario`): nome, email, cargo, senha_hash e ativo.
- **PROJETO** (`projeto_id`): nome, responsavel_id e vendedor_id.
- **MANUTENCAO** (`manutencao_id`): data_inicio_problema, tipo_manutencao, descricao_situacao, status, data_criacao, projeto_id, resumo, responsavel_id, data_limite e prioridade.
- **ANEXO** (`anexo_id`): os_id, nome_anexo, anexo_tipo, anexo_tamanho, data_anexo, id_usuario_envio, manutencao_id, projeto_id e conteudo_arquivo.

Cardinalidades: um usuario pode responder por zero ou varias manutencoes; uma manutencao possui no maximo um responsavel. Um projeto pode estar ligado a zero ou varias manutencoes; cada manutencao pode referenciar no maximo um projeto. Uma manutencao recebe zero ou varios anexos; cada anexo deste fluxo pertence a uma manutencao. Um usuario pode enviar zero ou varios anexos; cada anexo registra no maximo um remetente. O diagrama ER e a orientacao para reproduzir o modelo no BRModelo estao no arquivo da Parte 1.

### Modelo logico e normalizacao

O modelo relacional e formado por `usuarios`, `projetos`, `manutencoes` e `anexo`. Cada tabela tem PK propria; as FKs conectam manutencoes aos usuarios/projetos e anexos a manutencoes/usuarios/projetos. Tipos, nulabilidade, restricoes e regras `ON DELETE`/`ON UPDATE` estao alinhados ao DDL e detalhados no dicionario. A separacao dos dados de usuario, projeto e arquivo evita dependencias transitivas e atende a 3FN neste recorte.

## Parte 2 — DDL

O arquivo `01_ddl_criacao_tabelas.sql` cria a base `API2`, as quatro tabelas, PKs, FKs, `UNIQUE`, `CHECK` e indices. Execute em MySQL 8.0.16 ou superior para que as constraints `CHECK` sejam aplicadas.

## Parte 3A — DML

O arquivo `02_dml_insercao_dados.sql` contem **50 comandos `INSERT INTO ... VALUES (...)` individuais por tabela**, totalizando 200: 50 usuarios, 50 projetos, 50 manutencoes e 50 anexos. Os IDs e referencias foram preparados para execucao na base vazia criada pelo DDL. As senhas sao hashes ficticios e nao servem para autenticacao real.

Conferencia apos inserir:

```sql
SELECT 'usuarios' AS tabela, COUNT(*) AS linhas FROM usuarios
UNION ALL SELECT 'projetos', COUNT(*) FROM projetos
UNION ALL SELECT 'manutencoes', COUNT(*) FROM manutencoes
UNION ALL SELECT 'anexo', COUNT(*) FROM anexo;
```

Saida esperada:

```text
+-------------+--------+
| tabela      | linhas |
+-------------+--------+
| usuarios    | 50     |
| projetos    | 50     |
| manutencoes | 50     |
| anexo       | 50     |
+-------------+--------+
```

## Parte 3B — programacao em banco de dados

O codigo integral dos objetos esta em `03_programacao_bd.sql`. Os exemplos abaixo sao para execucao apos DDL, DML e criacao das rotinas, nessa ordem. As saidas sao **esperadas**, nao prints coletados de uma sessao MySQL; cole nos espacos as capturas reais obtidas no Workbench/CLI.

### Stored procedures (6)

| Objeto | Problema resolvido | SQL de teste | Retorno esperado |
|---|---|---|---|
| `sp_criar_manutencao` | Valida dados, converte `em_andamento` para o ENUM persistido e cria a manutencao. | `SET @id = NULL; SET @status = NULL; CALL sp_criar_manutencao(CURRENT_DATE(), 'corretiva', 'Teste de criacao', 'em_andamento', 'alta', 'Teste de manutencao', 2, 1, DATE_ADD(CURRENT_DATE(), INTERVAL 10 DAY), @id, @status); SELECT @id, @status;` | Na primeira execucao apos os 50 seeds: `@id = 51`, `@status = 'em andamento'`. **Print MySQL:** [colar aqui]. |
| `sp_resumo_manutencao` | Retorna resumo, responsavel, projeto e quantidade de anexos por manutencao, usando a view. | `CALL sp_resumo_manutencao(1);` | Uma linha para a manutencao 1; projeto `Projeto de teste 01`, responsavel `Usuario suporte de teste`, total de anexos `1`. Datas sao relativas a data de execucao. **Print:** [colar aqui]. |
| `sp_manutencoes_por_prioridade` | Lista manutencoes filtradas por prioridade com `INNER JOIN`, `LEFT JOIN` e subconsulta `IN`. | `CALL sp_manutencoes_por_prioridade('critica');` | 13 linhas, IDs 2, 6, 10, ..., 50. **Print:** [colar aqui]. |
| `sp_contagem_manutencoes_por_status` | Conta manutencoes por status, exibindo inclusive grupos sem registros por meio de `RIGHT JOIN` e `GROUP BY`. | `CALL sp_contagem_manutencoes_por_status();` | `aberta=13`, `em andamento=13`, `concluida=12`, `cancelada=12`. **Print:** [colar aqui]. |
| `sp_projetos_com_manutencoes` | Resume quantidade, data minima e prazo maximo por projeto com agregacoes e `EXISTS`. | `CALL sp_projetos_com_manutencoes();` | 50 linhas; cada projeto tem uma manutencao. Para o projeto 1: quantidade 1, primeiro problema 60 dias antes da execucao e maior prazo 15 dias antes. **Print:** [colar aqui]. |
| `sp_manutencoes_vencidas_cursor` | Percorre manutencoes vencidas ainda abertas/em andamento usando `CURSOR`. | `CALL sp_manutencoes_vencidas_cursor();` | `total_manutencoes_vencidas = 13`; IDs `1,5,9,13,17,21,25,29,33,37,41,45,49`. **Print:** [colar aqui]. |

### Functions (6)

| Objeto | Problema resolvido | SQL de teste | Retorno esperado |
|---|---|---|---|
| `fn_projeto_existe` | Verifica se o projeto opcional informado existe; `NULL` significa ausencia de vinculo. | `SELECT fn_projeto_existe(1), fn_projeto_existe(999999), fn_projeto_existe(NULL);` | `1`, `0`, `1`. **Print:** [colar aqui]. |
| `fn_resumo_manutencao_valido` | Aplica a regra de resumo nao vazio e limitado a 255 caracteres. | `SELECT fn_resumo_manutencao_valido('Resumo de teste'), fn_resumo_manutencao_valido('');` | `1`, `0`. **Print:** [colar aqui]. |
| `fn_total_anexos_manutencao` | Conta anexos vinculados a uma manutencao. | `SELECT fn_total_anexos_manutencao(1);` | `1`. **Print:** [colar aqui]. |
| `fn_responsavel_tem_manutencao_critica` | Verifica se o responsavel tem manutencao critica nao cancelada. | `SELECT fn_responsavel_tem_manutencao_critica(2);` | `1`. **Print:** [colar aqui]. |
| `fn_percentual_manutencoes_concluidas_projeto` | Calcula o percentual de manutencoes concluidas do projeto. | `SELECT fn_percentual_manutencoes_concluidas_projeto(3);` | `100.00`. **Print:** [colar aqui]. |
| `fn_media_prazo_manutencoes_projeto` | Calcula a media, em dias, entre inicio do problema e prazo final. | `SELECT fn_media_prazo_manutencoes_projeto(1);` | `45.00`. **Print:** [colar aqui]. |

### Triggers (6)

As cinco primeiras chamadas abaixo devem ser rejeitadas com SQLSTATE `45000` e a mensagem de validacao descrita no trigger. Execute-as individualmente.

| Objeto | Problema resolvido | SQL de teste | Retorno esperado |
|---|---|---|---|
| `trg_manutencao_bi_resumo` | Impede resumo ausente ou vazio. | `INSERT INTO manutencoes (data_inicio_problema,tipo_manutencao,descricao_situacao,status,projeto_id,resumo,responsavel_id,data_limite,prioridade) VALUES (CURRENT_DATE(),'corretiva','Teste','aberta',1,'',2,CURRENT_DATE(),'baixa');` | Erro: `Resumo obrigatorio de ate 255 caracteres.` **Print:** [colar aqui]. |
| `trg_manutencao_bi_descricao` | Impede descricao vazia ou maior que 5000 caracteres. | `INSERT INTO manutencoes (data_inicio_problema,tipo_manutencao,descricao_situacao,status,projeto_id,resumo,responsavel_id,data_limite,prioridade) VALUES (CURRENT_DATE(),'corretiva',' ','aberta',1,'Teste',2,CURRENT_DATE(),'baixa');` | Erro: `Descricao obrigatoria de ate 5000 caracteres.` **Print:** [colar aqui]. |
| `trg_manutencao_bi_responsavel` | Exige responsavel existente, ativo e com cargo `suporte`. | `INSERT INTO manutencoes (data_inicio_problema,tipo_manutencao,descricao_situacao,status,projeto_id,resumo,responsavel_id,data_limite,prioridade) VALUES (CURRENT_DATE(),'corretiva','Teste','aberta',1,'Teste',1,CURRENT_DATE(),'baixa');` | Erro: `Responsavel deve ser usuario de suporte ativo.` **Print:** [colar aqui]. |
| `trg_manutencao_bi_projeto` | Rejeita ID de projeto inexistente. | `INSERT INTO manutencoes (data_inicio_problema,tipo_manutencao,descricao_situacao,status,projeto_id,resumo,responsavel_id,data_limite,prioridade) VALUES (CURRENT_DATE(),'corretiva','Teste','aberta',999999,'Teste',2,CURRENT_DATE(),'baixa');` | Erro: `Projeto informado nao existe.` **Print:** [colar aqui]. |
| `trg_anexo_bi_vinculo_manutencao` | Garante que o anexo esteja ligado somente a uma manutencao neste recorte. | `INSERT INTO anexo (os_id,nome_anexo,anexo_tipo,anexo_tamanho,id_usuario_envio,manutencao_id,projeto_id,conteudo_arquivo) VALUES (1,'teste.txt','text/plain',1,2,1,NULL,'x');` | Erro: `Anexo deve estar vinculado somente a manutencao.` **Print:** [colar aqui]. |
| `trg_anexo_bi_tamanho` | Registra o tamanho real do conteudo binario recebido. | `START TRANSACTION; INSERT INTO anexo (os_id,nome_anexo,anexo_tipo,anexo_tamanho,id_usuario_envio,manutencao_id,projeto_id,conteudo_arquivo) VALUES (NULL,'teste.txt','text/plain',0,2,1,NULL,CONVERT('teste' USING binary)); SELECT anexo_tamanho FROM anexo WHERE anexo_id=LAST_INSERT_ID(); ROLLBACK;` | A consulta retorna `5` bytes; a transacao e desfeita ao final. **Print:** [colar aqui]. |

### View e conceitos relacionais utilizados

`vw_manutencoes_resumo` consolida manutencao, projeto, responsavel e total de anexos com `LEFT JOIN`, `COUNT` e `GROUP BY`. As procedures usam tambem `INNER JOIN`, `RIGHT JOIN`, subconsultas `IN`/`EXISTS`, cursor e agregacoes `COUNT`, `SUM`, `AVG`, `MIN` e `MAX`.

## Parte 4 — dicionario

O dicionario completo campo a campo, com tipos, obrigatoriedade, PK/FK, regras e descricao de negocio esta em `04_dicionario_de_dados.md`.

## Parte 5 — integracao com a API

Na rota existente `POST /api/manutencoes` (`backend/src/manutencoes.ts`), mantenha autenticacao, validacoes de entrada e decodificacao dos anexos. Substitua o `INSERT` direto na tabela `manutencoes` pelo helper de `05_integracao_api.ts`, passando o ID do usuario autenticado como `responsavelId`, o projeto opcional e os dados ja validados. O helper:

1. abre uma transacao MySQL;
2. chama `SELECT fn_projeto_existe(?)` para validar o vinculo opcional;
3. chama `sp_criar_manutencao(...)`, que valida o responsavel e dados, persiste a manutencao e devolve o ID/status;
4. grava cada anexo validado na tabela `anexo`;
5. confirma a transacao e devolve `manutencaoId` e status no formato esperado pela API; em caso de erro, desfaz a transacao e propaga o erro.

Adicione o import no topo de `manutencoes.ts`:

```ts
import {
  criarManutencaoNoBanco,
  ProjetoNaoEncontradoError,
} from "./05_integracao_api.js";
```

No corpo da rota, apos as validacoes existentes:

```ts
try {
  const criada = await criarManutencaoNoBanco({
    dataInicioProblema: data_inicio_problema,
    tipoManutencao: tipo_manutencao,
    descricaoSituacao: descricao_situacao.trim(),
    status: statusFinal,
    prioridade: prioridadeFinal,
    resumo: resumo.trim(),
    responsavelId: user.id,
    projetoId: projeto_id ? Number(projeto_id) : null,
    dataLimite: data_limite,
    anexos: arquivos,
  });

  return res.status(201).json({
    message: "Manutenção criada com sucesso!",
    manutencao: { manutencao_id: criada.manutencaoId, status: criada.status },
  });
} catch (error) {
  if (error instanceof ProjetoNaoEncontradoError) {
    return res.status(400).json({ message: error.message });
  }
  throw error;
}
```

O erro nao tratado segue para o `catch` externo que ja registra o problema e retorna HTTP 500. A implementacao nao cria notificacoes nem registros de historico.

## Execucao e evidencia

Ordem de execucao no MySQL Workbench/CLI:

1. `01_ddl_criacao_tabelas.sql`
2. `02_dml_insercao_dados.sql`
3. `03_programacao_bd.sql`
4. consultas de teste desta documentacao

Os scripts selecionam o schema `API2`; configure `DB_NAME=API2` na API ou ajuste a instrucao `USE` para o nome ja configurado no `.env` do projeto.

Cole nos campos `[colar aqui]` os prints reais das chamadas e retornos executados no MySQL.

## Ajustes de escopo

Foram retirados recursos gerais do sistema sem dependencia para este fluxo (OS, equipes, notificacoes e historico), rotinas associadas a esses recursos, exemplos repetidos e tecnicas nao MySQL. Foram mantidos projetos e anexos porque a rota de criacao de manutencao pode referenciar um projeto e receber arquivos.
