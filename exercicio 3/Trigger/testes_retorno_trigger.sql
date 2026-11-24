-- Trigger 1: trg_manutencao_bi_resumo
-- (a) BLOQUEIA: resumo vazio
INSERT INTO manutencoes (data_inicio_problema,tipo_manutencao,descricao_situacao,status,prioridade,resumo,responsavel_id,data_limite)
VALUES (CURRENT_DATE(),'corretiva','Descricao ok','aberta','media','   ',2,DATE_ADD(CURRENT_DATE(),INTERVAL 10 DAY));
-- (b) PERMITE: resumo preenchido
INSERT INTO manutencoes (data_inicio_problema,tipo_manutencao,descricao_situacao,status,prioridade,resumo,responsavel_id,data_limite)
VALUES (CURRENT_DATE(),'corretiva','Descricao ok','aberta','media','Teste trigger 1',2,DATE_ADD(CURRENT_DATE(),INTERVAL 10 DAY));
SELECT manutencao_id, resumo FROM manutencoes WHERE resumo = 'Teste trigger 1';

-- Trigger 2: trg_manutencao_bi_descricao
-- (a) BLOQUEIA: descrição vazia
INSERT INTO manutencoes (data_inicio_problema,tipo_manutencao,descricao_situacao,status,prioridade,resumo,responsavel_id,data_limite)
VALUES (CURRENT_DATE(),'corretiva','   ','aberta','media','Resumo ok',2,DATE_ADD(CURRENT_DATE(),INTERVAL 10 DAY));
-- (b) PERMITE: descrição preenchida
INSERT INTO manutencoes (data_inicio_problema,tipo_manutencao,descricao_situacao,status,prioridade,resumo,responsavel_id,data_limite)
VALUES (CURRENT_DATE(),'corretiva','Descricao do teste do trigger 2','aberta','media','Teste trigger 2',2,DATE_ADD(CURRENT_DATE(),INTERVAL 10 DAY));
SELECT manutencao_id, descricao_situacao FROM manutencoes WHERE resumo = 'Teste trigger 2';

-- Trigger 3: trg_manutencao_bi_responsavel
-- (a) BLOQUEIA: responsável 4 é gestor
INSERT INTO manutencoes (data_inicio_problema,tipo_manutencao,descricao_situacao,status,prioridade,resumo,responsavel_id,data_limite)
VALUES (CURRENT_DATE(),'corretiva','Descricao ok','aberta','media','Resumo ok',4,DATE_ADD(CURRENT_DATE(),INTERVAL 10 DAY));
-- (b) PERMITE: responsável 2 é suporte ativo
INSERT INTO manutencoes (data_inicio_problema,tipo_manutencao,descricao_situacao,status,prioridade,resumo,responsavel_id,data_limite)
VALUES (CURRENT_DATE(),'corretiva','Descricao ok','aberta','media','Teste trigger 3',2,DATE_ADD(CURRENT_DATE(),INTERVAL 10 DAY));
SELECT m.manutencao_id, m.resumo, u.nome, u.cargo FROM manutencoes m JOIN usuarios u ON u.id_usuario = m.responsavel_id WHERE m.resumo = 'Teste trigger 3';

-- Trigger 4: trg_manutencao_bi_projeto
-- (a) BLOQUEIA: projeto 99999 não existe
INSERT INTO manutencoes (data_inicio_problema,tipo_manutencao,descricao_situacao,status,prioridade,resumo,responsavel_id,projeto_id,data_limite)
VALUES (CURRENT_DATE(),'corretiva','Descricao ok','aberta','media','Resumo ok',2,99999,DATE_ADD(CURRENT_DATE(),INTERVAL 10 DAY));
-- (b) PERMITE: projeto 1 existe
INSERT INTO manutencoes (data_inicio_problema,tipo_manutencao,descricao_situacao,status,prioridade,resumo,responsavel_id,projeto_id,data_limite)
VALUES (CURRENT_DATE(),'corretiva','Descricao ok','aberta','media','Teste trigger 4',2,1,DATE_ADD(CURRENT_DATE(),INTERVAL 10 DAY));
SELECT manutencao_id, resumo, projeto_id FROM manutencoes WHERE resumo = 'Teste trigger 4';

-- Trigger 5: trg_anexo_bi_vinculo_manutencao
-- (a) BLOQUEIA: anexo ligado a O.S.
INSERT INTO anexo (os_id,nome_anexo,anexo_tipo,conteudo_arquivo)
VALUES (1,'laudo.pdf','application/pdf','abc');
-- (b) PERMITE: anexo ligado só a uma manutenção
INSERT INTO anexo (manutencao_id,nome_anexo,anexo_tipo,conteudo_arquivo)
VALUES (1,'teste_trigger5.pdf','application/pdf','abc');
SELECT anexo_id, nome_anexo, manutencao_id, os_id, projeto_id FROM anexo WHERE nome_anexo = 'teste_trigger5.pdf';

-- Trigger 6: trg_anexo_bi_tamanho
INSERT INTO anexo (manutencao_id,nome_anexo,anexo_tipo,anexo_tamanho,conteudo_arquivo)
VALUES (1,'foto_teste.jpg','image/jpeg',999999,'conteudo de teste');
SELECT anexo_id, nome_anexo, anexo_tamanho FROM anexo WHERE nome_anexo = 'foto_teste.jpg';