import { Router } from 'express';
import { AdminParametrosController } from '../controllers/admin/adminParametrosController';
import { AdminUsuariosController } from '../controllers/admin/adminUsuariosController';
import { AdminDepartamentosController } from '../controllers/admin/adminDepartamentosController';
import { AdminReservasController } from '../controllers/admin/adminReservasController';
import { FacilitiesController } from '../controllers/admin/facilitiesController';
import { RelatorioController } from '../controllers/relatorioController';
import {
  authenticateToken,
  authenticateAdminMfa,
  requirePermission,
  requireAdmin,
  requireAdminOrTi,
  requireTi
} from '../middleware/auth';
import { adminLimiter, batchLimiter, exportLimiter, heavyQueryLimiter, userActionLimiter } from '../middleware/rateLimiter';
import { validateRequest } from '../middleware/validateRequest';
import {
  criarUsuarioSchema,
  editarUsuarioSchema,
  colocarManutencaoSchema,
  updateParametrosSchema,
  usuarioListQuerySchema,
  alterarStatusUsuarioSchema,
  resetSenhaUsuarioSchema,
  importarLoteUsuariosSchema,
  criarDepartamentoSchema,
  idParamSchema,
  adminReservaQuerySchema,
  justificativaSchema,
  limpezaNoShowSchema,
  singleDateQuerySchema,
  relatorioQuerySchema,
  facilitiesQuerySchema,
  paginationQuerySchema
} from '../schemas';

const router = Router();

router.use(adminLimiter);
router.use(authenticateToken);
router.use(authenticateAdminMfa);

router.get('/parametros', requirePermission('config:read'), AdminParametrosController.getParametros);
router.put('/parametros', userActionLimiter, requirePermission('config:write'), validateRequest({ body: updateParametrosSchema }), AdminParametrosController.updateParametros);
router.post('/limpeza-noshow', userActionLimiter, requirePermission('config:write'), validateRequest({ body: limpezaNoShowSchema }), AdminParametrosController.executarLimpezaNoShow);
router.get('/relatorio/exportar', exportLimiter, requirePermission('config:write'), validateRequest({ query: singleDateQuerySchema }), AdminParametrosController.exportarRelatorioCsv);

router.get('/relatorios/analytics', requirePermission('relatorios:read'), validateRequest({ query: relatorioQuerySchema }), RelatorioController.getAnalytics);
router.get('/relatorios/dados', requirePermission('relatorios:read'), validateRequest({ query: relatorioQuerySchema }), RelatorioController.getDadosRelatorio);
router.get('/relatorios/exportar/xlsx', exportLimiter, requirePermission('relatorios:write'), validateRequest({ query: relatorioQuerySchema }), RelatorioController.exportarXlsx);
router.get('/relatorios/exportar/pdf', exportLimiter, requirePermission('relatorios:write'), validateRequest({ query: relatorioQuerySchema }), RelatorioController.exportarPdf);

router.get('/usuarios', heavyQueryLimiter, requirePermission('usuarios:read'), validateRequest({ query: usuarioListQuerySchema }), AdminUsuariosController.getUsuarios);
router.post('/usuarios', userActionLimiter, requirePermission('usuarios:write'), validateRequest({ body: criarUsuarioSchema }), AdminUsuariosController.criarUsuario);
router.put('/usuarios/:id', userActionLimiter, requirePermission('usuarios:write'), validateRequest({ params: idParamSchema, body: editarUsuarioSchema }), AdminUsuariosController.updateUsuario);
router.patch('/usuarios/:id/status', userActionLimiter, requirePermission('usuarios:write'), validateRequest({ params: idParamSchema, body: alterarStatusUsuarioSchema }), AdminUsuariosController.toggleStatusUsuario);
router.post('/usuarios/:id/reset-senha', userActionLimiter, requirePermission('usuarios:write'), validateRequest({ params: idParamSchema, body: resetSenhaUsuarioSchema }), AdminUsuariosController.resetSenhaUsuario);
router.post('/usuarios/importar-lote', batchLimiter, requirePermission('usuarios:write'), validateRequest({ body: importarLoteUsuariosSchema }), AdminUsuariosController.importarLoteUsuarios);

router.get('/departamentos', requirePermission('usuarios:read'), AdminDepartamentosController.getDepartamentos);
router.post('/departamentos', userActionLimiter, requirePermission('usuarios:write'), validateRequest({ body: criarDepartamentoSchema }), AdminDepartamentosController.criarDepartamento);

router.get('/reservas', heavyQueryLimiter, requirePermission('reservas:read'), validateRequest({ query: adminReservaQuerySchema }), AdminReservasController.getReservas);
router.post('/reservas/:id/cancelar', userActionLimiter, requireAdmin, validateRequest({ params: idParamSchema, body: justificativaSchema }), AdminReservasController.cancelarReservaAdmin);

router.get('/cadeiras/manutencao', requirePermission('infra:read'), validateRequest({ query: facilitiesQuerySchema }), FacilitiesController.getCadeirasManutencao);
router.get('/cadeiras/todas', requirePermission('infra:read'), validateRequest({ query: facilitiesQuerySchema }), FacilitiesController.getTodasCadeiras);
router.post('/cadeiras/:id/manutencao', userActionLimiter, requirePermission('infra:write'), validateRequest({ params: idParamSchema, body: colocarManutencaoSchema }), FacilitiesController.colocarCadeiraEmManutencao);
router.post('/cadeiras/:id/liberar', userActionLimiter, requirePermission('infra:write'), validateRequest({ params: idParamSchema }), FacilitiesController.liberarCadeiraManutencao);
router.get('/cadeiras/:id/historico', requirePermission('infra:read'), validateRequest({ params: idParamSchema, query: paginationQuerySchema }), FacilitiesController.getHistoricoCadeira);

export default router;



