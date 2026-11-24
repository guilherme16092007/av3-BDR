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