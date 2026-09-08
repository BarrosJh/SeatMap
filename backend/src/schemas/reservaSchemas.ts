import { z } from 'zod';
import { DateTime } from 'luxon';

const DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;

export const criarReservaSchema = z.object({
  cadeiraId: z.number().int().positive('ID de cadeira inválido'),
  data: z.string().regex(DATE_REGEX, 'Data deve estar no formato YYYY-MM-DD').optional(),
  dataReserva: z.string().regex(DATE_REGEX, 'Data deve estar no formato YYYY-MM-DD').optional()
}).refine(data => data.data || data.dataReserva, {
  message: 'Data da reserva é obrigatória.'
});

export const fazerCheckinSchema = z.object({
  cadeiraId: z.number().optional()
});

export const idParamSchema = z.object({
  id: z.string().regex(/^\d+$/, { message: 'ID inválido.' }).transform(v => parseInt(v, 10))
});


