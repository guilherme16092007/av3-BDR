-- Esquema MySQL para o fluxo basico de criacao de manutencao.
-- Contem somente usuarios, projetos, manutencoes e anexos da manutencao.
-- Nao substitui o script.sql completo da API em producao.

CREATE DATABASE IF NOT EXISTS API2
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE API2;

CREATE TABLE usuarios (
    id_usuario INT NOT NULL AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL,
    cargo ENUM(
        'superusuario',
        'gestor',
        'comercial',
        'suporte',
        'producao',
        'software',
        'implantacao',
        'monitoramento'
    ) NOT NULL,
    senha_hash VARCHAR(255) NOT NULL,
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id_usuario),
    UNIQUE KEY uq_usuarios_email (email)
) ENGINE=InnoDB;

CREATE TABLE projetos (
    projeto_id INT NOT NULL AUTO_INCREMENT,
    nome VARCHAR(150) NOT NULL,
    responsavel_id INT NULL,
    vendedor_id INT NULL,
    PRIMARY KEY (projeto_id),
    KEY idx_projeto_responsavel (responsavel_id),
    KEY idx_projeto_vendedor (vendedor_id),
    CONSTRAINT fk_projeto_responsavel
        FOREIGN KEY (responsavel_id) REFERENCES usuarios(id_usuario)
        ON DELETE SET NULL ON UPDATE RESTRICT,
    CONSTRAINT fk_projeto_vendedor
        FOREIGN KEY (vendedor_id) REFERENCES usuarios(id_usuario)
        ON DELETE SET NULL ON UPDATE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE manutencoes (
    manutencao_id INT NOT NULL AUTO_INCREMENT,
    data_inicio_problema DATE NOT NULL,
    tipo_manutencao ENUM('corretiva', 'preventiva', 'evolutiva', 'adaptativa') NOT NULL,
    descricao_situacao TEXT NOT NULL,
    status ENUM('aberta', 'em andamento', 'concluida', 'cancelada') NOT NULL DEFAULT 'aberta',
    data_criacao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    projeto_id INT NULL,
    resumo VARCHAR(255) NULL,
    responsavel_id INT NULL,
    data_limite DATE NULL,
    prioridade ENUM('baixa', 'media', 'alta', 'critica') NOT NULL DEFAULT 'media',
    PRIMARY KEY (manutencao_id),
    KEY idx_manutencao_projeto (projeto_id),
    KEY idx_manutencao_responsavel (responsavel_id),
    KEY idx_manutencao_status_prioridade (status, prioridade),
    CONSTRAINT fk_manutencao_projeto
        FOREIGN KEY (projeto_id) REFERENCES projetos(projeto_id)
        ON DELETE SET NULL ON UPDATE RESTRICT,
    CONSTRAINT fk_manutencao_responsavel
        FOREIGN KEY (responsavel_id) REFERENCES usuarios(id_usuario)
        ON DELETE SET NULL ON UPDATE RESTRICT,
    CONSTRAINT chk_manutencao_resumo
        CHECK (resumo IS NULL OR CHAR_LENGTH(TRIM(resumo)) BETWEEN 1 AND 255),
    CONSTRAINT chk_manutencao_descricao
        CHECK (CHAR_LENGTH(TRIM(descricao_situacao)) BETWEEN 1 AND 5000)
) ENGINE=InnoDB;

CREATE TABLE anexo (
    anexo_id INT NOT NULL AUTO_INCREMENT,
    os_id INT NULL,
    nome_anexo VARCHAR(255) NOT NULL,
    anexo_tipo VARCHAR(150) NOT NULL,
    anexo_tamanho BIGINT UNSIGNED NULL,
    data_anexo DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario_envio INT NULL,
    manutencao_id INT NULL,
    projeto_id INT NULL,
    conteudo_arquivo LONGBLOB NOT NULL,
    PRIMARY KEY (anexo_id),
    KEY idx_anexo_manutencao (manutencao_id),
    KEY idx_anexo_projeto (projeto_id),
    CONSTRAINT fk_anexo_manutencao
        FOREIGN KEY (manutencao_id) REFERENCES manutencoes(manutencao_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_anexo_projeto
        FOREIGN KEY (projeto_id) REFERENCES projetos(projeto_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_anexo_usuario_envio
        FOREIGN KEY (id_usuario_envio) REFERENCES usuarios(id_usuario)
        ON DELETE SET NULL ON UPDATE RESTRICT,
    CONSTRAINT chk_anexo_vinculo_manutencao
        CHECK (os_id IS NULL AND manutencao_id IS NOT NULL AND projeto_id IS NULL)
) ENGINE=InnoDB;
