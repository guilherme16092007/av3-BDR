-- Rotinas MySQL exclusivas do fluxo de criacao de manutencao.
-- Requer o DDL de exercicio 1/01_ddl_criacao_tabelas.sql.

USE API2;

CREATE OR REPLACE VIEW vw_manutencoes_resumo AS
SELECT
    m.manutencao_id,
    m.resumo,
    m.tipo_manutencao,
    m.status,
    m.prioridade,
    m.data_inicio_problema,
    m.data_limite,
    m.projeto_id,
    p.nome AS projeto_nome,
    m.responsavel_id,
    u.nome AS responsavel_nome,
    COUNT(DISTINCT a.anexo_id) AS total_anexos
FROM manutencoes AS m
LEFT JOIN projetos AS p ON p.projeto_id = m.projeto_id
LEFT JOIN usuarios AS u ON u.id_usuario = m.responsavel_id
LEFT JOIN anexo AS a ON a.manutencao_id = m.manutencao_id
GROUP BY
    m.manutencao_id, m.resumo, m.tipo_manutencao, m.status, m.prioridade,
    m.data_inicio_problema, m.data_limite, m.projeto_id, p.nome,
    m.responsavel_id, u.nome;

DELIMITER //

-- Function 1: valida o vinculo opcional com um projeto existente.
CREATE FUNCTION fn_projeto_existe(p_projeto_id INT)
RETURNS TINYINT
READS SQL DATA
BEGIN
    DECLARE v_existe TINYINT DEFAULT 0;
    IF p_projeto_id IS NULL THEN
        RETURN 1;
    END IF;
    SELECT EXISTS(
        SELECT 1 FROM projetos WHERE projeto_id = p_projeto_id
    ) INTO v_existe;
    RETURN v_existe;
END //

-- Function 2: verifica a regra de resumo exigido no POST da API.
CREATE FUNCTION fn_resumo_manutencao_valido(p_resumo VARCHAR(255))
RETURNS TINYINT
DETERMINISTIC
BEGIN
    RETURN p_resumo IS NOT NULL
       AND CHAR_LENGTH(TRIM(p_resumo)) BETWEEN 1 AND 255;
END //

-- Function 3: conta anexos associados a uma manutencao.
CREATE FUNCTION fn_total_anexos_manutencao(p_manutencao_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_total INT DEFAULT 0;
    SELECT COUNT(*) INTO v_total
    FROM anexo
    WHERE manutencao_id = p_manutencao_id;
    RETURN v_total;
END //

-- Function 4: verifica se o responsavel tem manutencao critica nao cancelada.
CREATE FUNCTION fn_responsavel_tem_manutencao_critica(p_responsavel_id INT)
RETURNS TINYINT
READS SQL DATA
BEGIN
    DECLARE v_existe TINYINT DEFAULT 0;
    SELECT EXISTS(
        SELECT 1
        FROM manutencoes
        WHERE responsavel_id = p_responsavel_id
          AND prioridade = 'critica'
          AND status <> 'cancelada'
    ) INTO v_existe;
    RETURN v_existe;
END //

-- Function 5: calcula percentual concluido de manutencoes de um projeto.
CREATE FUNCTION fn_percentual_manutencoes_concluidas_projeto(p_projeto_id INT)
RETURNS DECIMAL(5,2)
READS SQL DATA
BEGIN
    DECLARE v_total INT DEFAULT 0;
    DECLARE v_concluidas INT DEFAULT 0;
    SELECT COUNT(*), COALESCE(SUM(status = 'concluida'), 0)
    INTO v_total, v_concluidas
    FROM manutencoes
    WHERE projeto_id = p_projeto_id;
    RETURN IF(v_total = 0, 0, ROUND(v_concluidas * 100.0 / v_total, 2));
END //

-- Function 6: mede em dias o prazo medio no projeto.
CREATE FUNCTION fn_media_prazo_manutencoes_projeto(p_projeto_id INT)
RETURNS DECIMAL(8,2)
READS SQL DATA
BEGIN
    DECLARE v_media DECIMAL(8,2) DEFAULT NULL;
    SELECT ROUND(AVG(DATEDIFF(data_limite, data_inicio_problema)), 2)
    INTO v_media
    FROM manutencoes
    WHERE projeto_id = p_projeto_id
      AND data_limite IS NOT NULL;
    RETURN v_media;
END //

-- Procedure 1: cria a manutencao; em_andamento e persistido conforme o ENUM legado.
CREATE PROCEDURE sp_criar_manutencao(
    IN p_data_inicio_problema DATE,
    IN p_tipo_manutencao VARCHAR(20),
    IN p_descricao_situacao TEXT,
    IN p_status VARCHAR(20),
    IN p_prioridade VARCHAR(10),
    IN p_resumo VARCHAR(255),
    IN p_responsavel_id INT,
    IN p_projeto_id INT,
    IN p_data_limite DATE,
    OUT p_manutencao_id INT,
    OUT p_status_persistido VARCHAR(20)
)
BEGIN
    DECLARE v_status VARCHAR(20);

    IF p_data_inicio_problema IS NULL OR p_data_limite IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'As datas da manutencao sao obrigatorias.';
    END IF;
    IF p_tipo_manutencao NOT IN ('corretiva', 'preventiva', 'evolutiva', 'adaptativa') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tipo de manutencao invalido.';
    END IF;
    IF p_status NOT IN ('aberta', 'em_andamento', 'em andamento', 'concluida', 'cancelada') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Status de manutencao invalido.';
    END IF;
    IF p_prioridade NOT IN ('baixa', 'media', 'alta', 'critica') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Prioridade invalida.';
    END IF;
    IF fn_resumo_manutencao_valido(p_resumo) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Informe um resumo valido de ate 255 caracteres.';
    END IF;
    IF p_descricao_situacao IS NULL OR CHAR_LENGTH(TRIM(p_descricao_situacao)) NOT BETWEEN 1 AND 5000 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Informe uma descricao valida de ate 5000 caracteres.';
    END IF;
    IF p_responsavel_id IS NULL OR NOT EXISTS(
        SELECT 1 FROM usuarios
        WHERE id_usuario = p_responsavel_id AND cargo = 'suporte' AND ativo = TRUE
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O responsavel deve ser um usuario de suporte ativo.';
    END IF;
    IF fn_projeto_existe(p_projeto_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Projeto nao encontrado.';
    END IF;

    SET v_status = IF(p_status = 'em_andamento', 'em andamento', p_status);

    INSERT INTO manutencoes (
        data_inicio_problema, tipo_manutencao, descricao_situacao, status,
        prioridade, resumo, responsavel_id, projeto_id, data_limite
    ) VALUES (
        p_data_inicio_problema, p_tipo_manutencao, TRIM(p_descricao_situacao),
        v_status, p_prioridade, TRIM(p_resumo), p_responsavel_id, p_projeto_id,
        p_data_limite
    );

    SET p_manutencao_id = LAST_INSERT_ID();
    SET p_status_persistido = v_status;
END //

-- Procedure 2: consulta o registro criado com projeto, responsavel e anexos.
CREATE PROCEDURE sp_resumo_manutencao(IN p_manutencao_id INT)
BEGIN
    SELECT manutencao_id, resumo, tipo_manutencao, status, prioridade,
           data_inicio_problema, data_limite, projeto_id, projeto_nome,
           responsavel_id, responsavel_nome, total_anexos
    FROM vw_manutencoes_resumo
    WHERE manutencao_id = p_manutencao_id;
END //

-- Procedure 3: lista manutencoes por prioridade.
CREATE PROCEDURE sp_manutencoes_por_prioridade(IN p_prioridade VARCHAR(10))
BEGIN
    SELECT m.manutencao_id, m.resumo, m.status, m.prioridade,
           m.data_inicio_problema, m.data_limite,
           u.nome AS responsavel, p.nome AS projeto
    FROM manutencoes AS m
    INNER JOIN usuarios AS u ON u.id_usuario = m.responsavel_id
    LEFT JOIN projetos AS p ON p.projeto_id = m.projeto_id
    WHERE m.manutencao_id IN (
        SELECT manutencao_id FROM manutencoes WHERE prioridade = p_prioridade
    )
    ORDER BY m.data_limite, m.manutencao_id;
END //

-- Procedure 4: conta registros por status, inclusive os status sem ocorrencias.
CREATE PROCEDURE sp_contagem_manutencoes_por_status()
BEGIN
    SELECT s.status, COUNT(m.manutencao_id) AS total
    FROM manutencoes AS m
    RIGHT JOIN (
        SELECT 'aberta' AS status
        UNION ALL SELECT 'em andamento'
        UNION ALL SELECT 'concluida'
        UNION ALL SELECT 'cancelada'
    ) AS s ON s.status = m.status
    GROUP BY s.status
    ORDER BY s.status;
END //

-- Procedure 5: resume projetos que possuem manutencao.
CREATE PROCEDURE sp_projetos_com_manutencoes()
BEGIN
    SELECT p.projeto_id, p.nome, COUNT(m.manutencao_id) AS total_manutencoes,
           MIN(m.data_inicio_problema) AS primeiro_problema,
           MAX(m.data_limite) AS maior_prazo
    FROM projetos AS p
    LEFT JOIN manutencoes AS m ON m.projeto_id = p.projeto_id
    WHERE EXISTS (
        SELECT 1 FROM manutencoes AS mx WHERE mx.projeto_id = p.projeto_id
    )
    GROUP BY p.projeto_id, p.nome
    ORDER BY p.projeto_id;
END //

-- Procedure 6: percorre manutencoes vencidas ainda nao concluidas/canceladas.
CREATE PROCEDURE sp_manutencoes_vencidas_cursor()
BEGIN
    DECLARE v_fim BOOLEAN DEFAULT FALSE;
    DECLARE v_id INT;
    DECLARE v_total INT DEFAULT 0;
    DECLARE v_ids TEXT DEFAULT '';
    DECLARE cur_manutencoes CURSOR FOR
        SELECT manutencao_id
        FROM manutencoes
        WHERE data_limite < CURRENT_DATE()
          AND status NOT IN ('concluida', 'cancelada')
        ORDER BY data_limite, manutencao_id;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim = TRUE;

    OPEN cur_manutencoes;
    leitura: LOOP
        FETCH cur_manutencoes INTO v_id;
        IF v_fim THEN
            LEAVE leitura;
        END IF;
        SET v_total = v_total + 1;
        SET v_ids = CONCAT_WS(',', NULLIF(v_ids, ''), v_id);
    END LOOP;
    CLOSE cur_manutencoes;

    SELECT v_total AS total_manutencoes_vencidas, v_ids AS manutencao_ids;
END //

-- Trigger 1: bloqueia resumo ausente ou fora do limite da API.
CREATE TRIGGER trg_manutencao_bi_resumo
BEFORE INSERT ON manutencoes
FOR EACH ROW
BEGIN
    IF fn_resumo_manutencao_valido(NEW.resumo) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Resumo obrigatorio de ate 255 caracteres.';
    END IF;
END //

-- Trigger 2: bloqueia descricao vazia ou maior que 5000 caracteres.
CREATE TRIGGER trg_manutencao_bi_descricao
BEFORE INSERT ON manutencoes
FOR EACH ROW
BEGIN
    IF NEW.descricao_situacao IS NULL
       OR CHAR_LENGTH(TRIM(NEW.descricao_situacao)) NOT BETWEEN 1 AND 5000 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Descricao obrigatoria de ate 5000 caracteres.';
    END IF;
END //

-- Trigger 3: exige responsavel ativo no perfil suporte.
CREATE TRIGGER trg_manutencao_bi_responsavel
BEFORE INSERT ON manutencoes
FOR EACH ROW
BEGIN
    IF NEW.responsavel_id IS NULL OR NOT EXISTS(
        SELECT 1 FROM usuarios
        WHERE id_usuario = NEW.responsavel_id AND cargo = 'suporte' AND ativo = TRUE
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Responsavel deve ser usuario de suporte ativo.';
    END IF;
END //

-- Trigger 4: valida existencia do projeto opcional.
CREATE TRIGGER trg_manutencao_bi_projeto
BEFORE INSERT ON manutencoes
FOR EACH ROW
BEGIN
    IF fn_projeto_existe(NEW.projeto_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Projeto informado nao existe.';
    END IF;
END //

-- Trigger 5: anexo deste recorte deve pertencer somente a uma manutencao.
CREATE TRIGGER trg_anexo_bi_vinculo_manutencao
BEFORE INSERT ON anexo
FOR EACH ROW
BEGIN
    IF NEW.os_id IS NOT NULL OR NEW.manutencao_id IS NULL OR NEW.projeto_id IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Anexo deve estar vinculado somente a manutencao.';
    END IF;
END //

-- Trigger 6: calcula o tamanho real do arquivo binario.
CREATE TRIGGER trg_anexo_bi_tamanho
BEFORE INSERT ON anexo
FOR EACH ROW
BEGIN
    SET NEW.anexo_tamanho = OCTET_LENGTH(NEW.conteudo_arquivo);
END //

DELIMITER ;
