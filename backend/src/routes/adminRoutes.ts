import { Router } from 'express';
import { AdminParametrosController } from '../controllers/admin/adminParametrosController';
import { AdminUsuariosController } from '../controllers/admin/adminUsuariosController';
import { AdminDepartamentosController } from '../controllers/admin/adminDepartamentosController';
import { AdminReservasController } from '../controllers/admin/adminReservasController';
import { FacilitiesController } from '../controllers/admin/facilitiesController';
import { RelatorioController } from '../controllers/relatorioController';
import { authenticateToken, requireAdmin, requireAdminOrTi, authenticateAdminMfa } from '../middleware/auth';
import { adminLimiter } from '../middleware/rateLimiter';

const router = Router();

// Todas as rotas administrativas exigem autenticação do usuário, verificação de MFA e rate limit
router.use(adminLimiter);
router.use(authenticateToken);
router.use(authenticateAdminMfa);

// 1. Parâmetros e Políticas (RH Admin)
router.get('/parametros', requireAdmin, AdminParametrosController.getParametros);
router.put('/parametros', requireAdmin, AdminParametrosController.updateParametros);
router.post('/limpeza-noshow', requireAdmin, AdminParametrosController.executarLimpezaNoShow);
router.get('/relatorio/exportar', requireAdmin, AdminParametrosController.exportarRelatorioCsv);

// 2. Módulo Completo de Relatórios & BI (RH Admin)
router.get('/relatorios/analytics', requireAdmin, RelatorioController.getAnalytics);
router.get('/relatorios/dados', requireAdmin, RelatorioController.getDadosRelatorio);
router.get('/relatorios/exportar/xlsx', requireAdmin, RelatorioController.exportarXlsx);
router.get('/relatorios/exportar/pdf', requireAdmin, RelatorioController.exportarPdf);

// 3. Gestão de Usuários (RH & TI)
router.get('/usuarios', requireAdminOrTi, AdminUsuariosController.getUsuarios);
router.post('/usuarios', requireAdminOrTi, AdminUsuariosController.criarUsuario);
router.put('/usuarios/:id', requireAdminOrTi, AdminUsuariosController.updateUsuario);
router.patch('/usuarios/:id/status', requireAdminOrTi, AdminUsuariosController.toggleStatusUsuario);
router.put('/usuarios/:id/status', requireAdminOrTi, AdminUsuariosController.toggleStatusUsuario);
router.post('/usuarios/:id/reset-senha', requireAdminOrTi, AdminUsuariosController.resetSenhaUsuario);
router.post('/usuarios/importar-lote', requireAdminOrTi, AdminUsuariosController.importarLoteUsuarios);

// 4. Departamentos (RH & TI)
router.get('/departamentos', requireAdminOrTi, AdminDepartamentosController.getDepartamentos);
router.post('/departamentos', requireAdminOrTi, AdminDepartamentosController.criarDepartamento);

// 5. Gestão Global de Reservas & Cancelamento RH (RH Admin)
router.get('/reservas', requireAdmin, AdminReservasController.getReservas);
router.post('/reservas/:id/cancelar', requireAdmin, AdminReservasController.cancelarReservaAdmin);

// 6. Gestão Operacional de Assentos & Manutenção (Facilities / TI / RH)
router.get('/cadeiras/manutencao', requireAdminOrTi, FacilitiesController.getCadeirasManutencao);
router.get('/cadeiras/todas', requireAdminOrTi, FacilitiesController.getTodasCadeiras);
router.post('/cadeiras/:id/manutencao', requireAdminOrTi, FacilitiesController.colocarCadeiraEmManutencao);
router.post('/cadeiras/:id/liberar', requireAdminOrTi, FacilitiesController.liberarCadeiraManutencao);
router.get('/cadeiras/:id/historico', requireAdminOrTi, FacilitiesController.getHistoricoCadeira);

export default router;



