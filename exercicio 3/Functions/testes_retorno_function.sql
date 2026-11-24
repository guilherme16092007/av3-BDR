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
