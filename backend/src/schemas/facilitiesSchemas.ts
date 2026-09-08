import { z } from 'zod';

export const colocarManutencaoSchema = z.object({
  motivo: z.string().min(1, 'O motivo da manutenção é obrigatório').max(500),
  previsaoRetorno: z.string().datetime({ offset: true }).or(z.string().regex(/^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2}(\.\d{1,3})?)?Z?)?$/)).optional().nullable()
});

export const listarCadeirasFiltroSchema = z.object({
  escritorioId: z.string().optional(),
  busca: z.string().optional()
});
