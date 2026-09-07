import { Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth';
import { UsuarioService } from '../../services/usuarioService';
import { parseIdParam } from '../../utils/workWeekUtils';
import { logger } from '../../utils/logger';

export class AdminUsuariosController {
  public static async getUsuarios(req: AuthenticatedRequest, res: Response) {
    try {
      const { busca, departamentoId, perfil, ativo, limit = 100, offset = 0 } = req.query;
      const resultado = await UsuarioService.listarUsuarios({
        busca: busca as string | undefined,
        departamentoId: departamentoId as string | undefined,
        perfil: perfil as string | undefined,
        ativo: ativo as string | undefined,
        limit: parseInt(limit as string, 10) || 100,
        offset: parseInt(offset as string, 10) || 0
      });

      return res.status(200).json(resultado);
    } catch (error) {
      logger.error('[AdminUsuariosController.getUsuarios] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao listar usuários.' });
    }
  }

  public static async criarUsuario(req: AuthenticatedRequest, res: Response) {
    try {
      const operatorIsTi = req.user?.permissaoTi === true || req.user?.perfil === 'ADMIN_TI';
      const result = await UsuarioService.criarUsuario(req.body, operatorIsTi);

      if (!result.success) {
        return res.status(result.code || 400).json({ error: result.error });
      }

      return res.status(result.code || 201).json({
        message: result.message,
        usuario: result.usuario
      });
    } catch (error) {
      logger.error('[AdminUsuariosController.criarUsuario] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao criar usuário.' });
    }
  }

  public static async updateUsuario(req: AuthenticatedRequest, res: Response) {
    try {
      const numericId = parseIdParam(req.params.id);
      if (!numericId) {
        return res.status(400).json({ error: 'ID de usuário inválido.' });
      }

      const operatorIsTi = req.user?.permissaoTi === true || req.user?.perfil === 'ADMIN_TI';
      const result = await UsuarioService.updateUsuario(numericId, req.body, operatorIsTi);

      if (!result.success) {
        return res.status(result.code || 400).json({ error: result.error });
      }

      return res.status(result.code || 200).json({
        message: result.message,
        usuario: result.usuario
      });
    } catch (error) {
      logger.error('[AdminUsuariosController.updateUsuario] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao atualizar usuário.' });
    }
  }

  public static async toggleStatusUsuario(req: AuthenticatedRequest, res: Response) {
    try {
      const numericId = parseIdParam(req.params.id);
      if (!numericId) {
        return res.status(400).json({ error: 'ID de usuário inválido.' });
      }

      const { ativo } = req.body;
      const result = await UsuarioService.toggleStatusUsuario(numericId, ativo);

      if (!result.success) {
        return res.status(result.code || 400).json({ error: result.error });
      }

      return res.status(result.code || 200).json({
        message: result.message,
        usuario: result.usuario
      });
    } catch (error) {
      logger.error('[AdminUsuariosController.toggleStatusUsuario] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao alterar status do usuário.' });
    }
  }

  public static async resetSenhaUsuario(req: AuthenticatedRequest, res: Response) {
    try {
      const numericId = parseIdParam(req.params.id);
      if (!numericId) {
        return res.status(400).json({ error: 'ID de usuário inválido.' });
      }

      const { novaSenha } = req.body;
      const result = await UsuarioService.resetSenhaUsuario(numericId, novaSenha);

      if (!result.success) {
        return res.status(result.code || 400).json({ error: result.error });
      }

      return res.status(result.code || 200).json({
        message: result.message
      });
    } catch (error) {
      logger.error('[AdminUsuariosController.resetSenhaUsuario] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao redefinir senha do usuário.' });
    }
  }

  public static async importarLoteUsuarios(req: AuthenticatedRequest, res: Response) {
    try {
      const { usuarios, defaultSenha } = req.body;
      const operatorIsTi = req.user?.permissaoTi === true || req.user?.perfil === 'ADMIN_TI';
      const result = await UsuarioService.importarLoteUsuarios(usuarios, defaultSenha, operatorIsTi);

      if (!result.success) {
        return res.status(result.code || 400).json({ error: result.error });
      }

      return res.status(result.code || 200).json({
        message: result.message,
        criados: result.criados,
        atualizados: result.atualizados,
        total: result.total,
        erros: result.erros
      });
    } catch (error) {
      logger.error('[AdminUsuariosController.importarLoteUsuarios] Erro:', { correlationId: req.correlationId, error });
      return res.status(500).json({ error: 'Erro ao processar importação em lote.' });
    }
  }
}
