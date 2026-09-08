import { z } from 'zod';
import { DateTime } from 'luxon';

const DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;

const dateSchema = (paramName: string) =>
  z.string()
    .refine(
      val => DATE_REGEX.test(val) && DateTime.fromISO(val).isValid,
      { message: `Parâmetro ${paramName} inválido. Utilize o formato YYYY-MM-DD.` }
    );

export const relatorioFiltrosSchema = z.object({
  dataInicio: dateSchema('dataInicio').optional(),
  dataFim: dateSchema('dataFim').optional(),
  escritorioId: z.string().optional(),
  departamentoId: z.string().optional(),
  status: z.string().optional(),
  checkinStatus: z.string().optional(),
  busca: z.string().optional(),
  limit: z.string().regex(/^\d+$/).transform(v => parseInt(v, 10)).optional(),
  offset: z.string().regex(/^\d+$/).transform(v => parseInt(v, 10)).optional()
});

export const exportRelatorioSchema = relatorioFiltrosSchema.extend({
  formato: z.enum(['excel', 'pdf', 'csv']).optional()
});

