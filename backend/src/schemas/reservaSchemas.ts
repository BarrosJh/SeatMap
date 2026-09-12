import { z } from 'zod';
import { DateTime } from 'luxon';

const DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;

export const criarReservaSchema = z.object({
  cadeiraId: z.coerce.number().int().positive('ID de cadeira inválido'),
  dataReserva: z.string().regex(DATE_REGEX, 'Data deve estar no formato YYYY-MM-DD'),
  idempotencyKey: z.string().max(100).optional()
}).strict();

export const fazerCheckinSchema = z.object({
  cadeiraId: z.coerce.number().int().positive().optional()
}).strict();

export const idParamSchema = z.object({
  id: z.string().regex(/^\d+$/, { message: 'ID inválido.' }).transform(v => parseInt(v, 10))
}).strict();

export const paginationQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).max(100000).default(0)
}).strict();

export const dateQuerySchema = z.object({
  data: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Data deve estar no formato YYYY-MM-DD').optional()
}).strict();


