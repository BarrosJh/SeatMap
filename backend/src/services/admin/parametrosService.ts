import { ConfigService } from '../configService';
import { wsManager } from '../../websocket/wsServer';
import { validateSingleParam } from '../../schemas/parametrosSchemas';

export class ParametrosService {
  /**
   * Obtém todos os parâmetros de configuração do sistema
   */
  public static async getParametros() {
    return ConfigService.getAll();
  }

  /**
   * Atualiza parâmetros em lote com validação de whitelist e disparo de WebSocket
   */
  public static async updateParametros(configuracoes: any) {
    if (!configuracoes) {
      return { success: false, code: 400, error: 'Nenhuma configuração enviada para atualização.' };
    }

    const itemsToUpdate: { chave: string; valor: string; descricao?: string }[] = [];

    if (Array.isArray(configuracoes)) {
      for (const item of configuracoes) {
        if (item.chave && item.valor !== undefined) {
          const validation = validateSingleParam(item.chave, String(item.valor));
          if (!validation.valid) {
            return { success: false, code: 400, error: validation.error };
          }
          itemsToUpdate.push({ chave: item.chave, valor: String(item.valor), descricao: item.descricao });
        }
      }
    } else if (typeof configuracoes === 'object' && configuracoes !== null) {
      for (const [chave, valor] of Object.entries(configuracoes)) {
        const validation = validateSingleParam(chave, String(valor));
        if (!validation.valid) {
          return { success: false, code: 400, error: validation.error };
        }
        itemsToUpdate.push({ chave, valor: String(valor) });
      }
    }

    if (itemsToUpdate.length === 0) {
      return { success: false, code: 400, error: 'Nenhuma configuração válida enviada para atualização.' };
    }

    for (const item of itemsToUpdate) {
      await ConfigService.set(item.chave, item.valor, item.descricao);
    }

    const atualizadas = await ConfigService.getAll();
    const avisoAtualizado = await ConfigService.get('AVISO_GLOBAL_SISTEMA', '');
    wsManager.broadcastToAll({
      tipo: 'AVISO_GLOBAL_ATUALIZADO',
      aviso: avisoAtualizado
    });

    return {
      success: true,
      code: 200,
      message: 'Configurações atualizadas com sucesso.',
      parametros: atualizadas
    };
  }
}

