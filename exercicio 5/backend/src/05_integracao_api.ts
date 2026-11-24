import type { RowDataPacket } from "mysql2";
import { pool } from "./db.js";

type AnexoValidado = {
  nome: string;
  tipo: string;
  conteudo: Buffer;
};

type CriarManutencao = {
  dataInicioProblema: string;
  tipoManutencao: string;
  descricaoSituacao: string;
  status: string;
  prioridade: string;
  resumo: string;
  responsavelId: number;
  projetoId: number | null;
  dataLimite: string;
  anexos: AnexoValidado[];
};

type ProjetoExisteRow = RowDataPacket & { existe: number };
type ManutencaoCriadaRow = RowDataPacket & {
  manutencao_id: number | null;
  status_persistido: string | null;
};

export class ProjetoNaoEncontradoError extends Error {
  constructor() {
    super("Projeto nao encontrado.");
    this.name = "ProjetoNaoEncontradoError";
  }
}

export async function criarManutencaoNoBanco(
  dados: CriarManutencao,
): Promise<{ manutencaoId: number; status: string }> {
  const connection = await pool.getConnection();
  let transacaoIniciada = false;

  try {
    await connection.beginTransaction();
    transacaoIniciada = true;

    const [projetos] = await connection.execute<ProjetoExisteRow[]>(
      "SELECT fn_projeto_existe(?) AS existe",
      [dados.projetoId],
    );
    if (Number(projetos[0]?.existe) !== 1) {
      throw new ProjetoNaoEncontradoError();
    }

    await connection.query(
      `CALL sp_criar_manutencao(
        ?, ?, ?, ?, ?, ?, ?, ?, ?, @manutencao_id, @status_persistido
      )`,
      [
        dados.dataInicioProblema,
        dados.tipoManutencao,
        dados.descricaoSituacao,
        dados.status,
        dados.prioridade,
        dados.resumo,
        dados.responsavelId,
        dados.projetoId,
        dados.dataLimite,
      ],
    );

    const [resultado] = await connection.query<ManutencaoCriadaRow[]>(
      "SELECT @manutencao_id AS manutencao_id, @status_persistido AS status_persistido",
    );
    const manutencao = resultado[0];
    if (
      !manutencao ||
      manutencao.manutencao_id === null ||
      manutencao.status_persistido === null
    ) {
      throw new Error("A procedure nao retornou os dados da manutencao criada.");
    }

    for (const anexo of dados.anexos) {
      await connection.execute(
        `INSERT INTO anexo
          (os_id, nome_anexo, anexo_tipo, anexo_tamanho, id_usuario_envio,
           manutencao_id, projeto_id, conteudo_arquivo)
         VALUES (NULL, ?, ?, ?, ?, ?, NULL, ?)`,
        [
          anexo.nome,
          anexo.tipo,
          anexo.conteudo.length,
          dados.responsavelId,
          manutencao.manutencao_id,
          anexo.conteudo,
        ],
      );
    }

    await connection.commit();
    transacaoIniciada = false;

    return {
      manutencaoId: manutencao.manutencao_id,
      status:
        manutencao.status_persistido === "em andamento"
          ? "em_andamento"
          : manutencao.status_persistido,
    };
  } catch (error) {
    if (transacaoIniciada) {
      await connection.rollback();
    }
    throw error;
  } finally {
    connection.release();
  }
}
