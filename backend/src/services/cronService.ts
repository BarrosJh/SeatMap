import cron, { ScheduledTask } from 'node-cron';
import { logger } from '../utils/logger';
import { NoShowJobService } from './cron/jobs/noShowJobService';
import { AutoConclusionJobService } from './cron/jobs/autoConclusionJobService';
import { NoShowExecutionResult, AutoConclusionExecutionResult } from './cron/types';

export class CronService {
  private static tasks: ScheduledTask[] = [];
  private static activeExecutions: Set<Promise<any>> = new Set();

  public static init(): void {
    // 1. Executa verificação inicial no boot para limpar no-shows pendentes e concluir reservas passadas
    this.checkAndCancelNoShows().catch((err) => {
      logger.error('[Cron] Falha na verificação de No-Show no boot:', { error: err });
    });

    this.concluirReservasPassadas().catch((err) => {
      logger.error('[Cron] Falha na conclusão de reservas passadas no boot:', { error: err });
    });

    // 2. Agendador periódico a cada 1 minuto para checar o horário de corte de No-Show
    const noShowTask = cron.schedule('* * * * *', async () => {
      await this.checkAndCancelNoShows();
    }, {
      timezone: 'America/Sao_Paulo'
    });

    // 3. Agendador diário à meia-noite (00:01) para conclusão automática de reservas confirmadas do dia anterior
    const autoConclusionTask = cron.schedule('1 0 * * *', async () => {
      await this.concluirReservasPassadas();
    }, {
      timezone: 'America/Sao_Paulo'
    });

    this.tasks = [noShowTask, autoConclusionTask];

    logger.info('[Cron] Rotinas periódicas do SeatMap iniciadas (No-Show por minuto e Conclusão EOD diária no fuso America/Sao_Paulo)');
  }

  public static async checkAndCancelNoShows(): Promise<void> {
    try {
      await this.cancelExpiredNoShows();
    } catch (err) {
      logger.error('[Cron] Erro ao verificar horário de No-Show:', { error: err });
    }
  }

  public static stop(): void {
    for (const task of this.tasks) {
      task.stop();
    }
    this.tasks = [];
    logger.info('[Cron] Todas as rotinas agendadas do Cron foram interrompidas.');
  }

  /**
   * Aguarda o término de qualquer execução ativa do Cron durante o graceful shutdown (REL-04).
   */
  public static async waitForCompletion(timeoutMs: number = 5000): Promise<void> {
    this.stop();
    if (this.activeExecutions.size === 0) {
      return;
    }

    logger.info('[Cron] Aguardando conclusão de rotinas ativas em andamento...');
    let timer: NodeJS.Timeout | null = null;

    const timeoutPromise = new Promise<void>((resolve) => {
      timer = setTimeout(() => {
        logger.warn('[Cron] Timeout atingido aguardando conclusão das rotinas ativas.');
        resolve();
      }, timeoutMs);
      if (typeof timer && typeof timer.unref === 'function') {
        timer.unref();
      }
    });

    try {
      const allExecutions = Promise.allSettled(Array.from(this.activeExecutions));
      await Promise.race([allExecutions, timeoutPromise]);
    } catch (_) {
      // Falha capturada no log da própria rotina
    } finally {
      if (timer) clearTimeout(timer);
      this.activeExecutions.clear();
    }
  }

  /**
   * Cancela em lote reservas sem check-in expiradas (No-Show).
   */
  public static async cancelExpiredNoShows(forcedDate?: string): Promise<NoShowExecutionResult> {
    const executionPromise = NoShowJobService.execute(forcedDate);
    this.activeExecutions.add(executionPromise);
    try {
      return await executionPromise;
    } finally {
      this.activeExecutions.delete(executionPromise);
    }
  }

  /**
   * Conclui em lote reservas com check-in realizado de datas anteriores (EOD).
   */
  public static async concluirReservasPassadas(forcedDate?: string): Promise<AutoConclusionExecutionResult> {
    const executionPromise = AutoConclusionJobService.execute(forcedDate);
    this.activeExecutions.add(executionPromise);
    try {
      return await executionPromise;
    } finally {
      this.activeExecutions.delete(executionPromise);
    }
  }
}
