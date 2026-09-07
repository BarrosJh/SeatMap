import { Router } from 'express';
import { AdminController } from '../controllers/adminController';
import { RelatorioController } from '../controllers/relatorioController';
import { authenticateToken, requireAdmin, requireAdminOrTi, authenticateAdminMfa } from '../middleware/auth';
import { adminLimiter } from '../middleware/rateLimiter';

const router = Router();

// Todas as rotas administrativas exigem autenticação do usuário e rate limit
router.use(adminLimiter);
router.use(authenticateToken);

// 1. Parâmetros e Políticas (RH Admin)
router.get('/parametros', requireAdmin, AdminController.getParametros);
router.put('/parametros', requireAdmin, AdminController.updateParametros);
router.post('/limpeza-noshow', requireAdmin, AdminController.executarLimpezaNoShow);
router.get('/relatorio/exportar', requireAdmin, AdminController.exportarRelatorioCsv);

// 2. Módulo Completo de Relatórios & BI (RH Admin)
router.get('/relatorios/analytics', requireAdmin, RelatorioController.getAnalytics);
router.get('/relatorios/dados', requireAdmin, RelatorioController.getDadosRelatorio);
router.get('/relatorios/exportar/xlsx', requireAdmin, RelatorioController.exportarXlsx);
router.get('/relatorios/exportar/pdf', requireAdmin, RelatorioController.exportarPdf);

// 3. Gestão de Usuários (RH & TI)
router.get('/usuarios', requireAdminOrTi, AdminController.getUsuarios);
router.post('/usuarios', requireAdminOrTi, AdminController.criarUsuario);
router.put('/usuarios/:id', requireAdminOrTi, AdminController.updateUsuario);
router.patch('/usuarios/:id/status', requireAdminOrTi, AdminController.toggleStatusUsuario);
router.put('/usuarios/:id/status', requireAdminOrTi, AdminController.toggleStatusUsuario);
router.post('/usuarios/:id/status', requireAdminOrTi, AdminController.toggleStatusUsuario);
router.post('/usuarios/:id/reset-senha', requireAdminOrTi, AdminController.resetSenhaUsuario);
router.post('/usuarios/importar-lote', requireAdminOrTi, AdminController.importarLoteUsuarios);

// 4. Departamentos (RH & TI)
router.get('/departamentos', requireAdminOrTi, AdminController.getDepartamentos);
router.post('/departamentos', requireAdminOrTi, AdminController.criarDepartamento);

// 5. Gestão Global de Reservas & Cancelamento RH (RH Admin)
router.get('/reservas', requireAdmin, AdminController.getReservas);
router.post('/reservas/:id/cancelar', requireAdmin, AdminController.cancelarReservaAdmin);

// 6. Gestão Operacional de Assentos & Manutenção (Facilities / TI / RH)
router.get('/cadeiras/manutencao', requireAdminOrTi, AdminController.getCadeirasManutencao);
router.get('/cadeiras/todas', requireAdminOrTi, AdminController.getTodasCadeiras);
router.post('/cadeiras/:id/manutencao', requireAdminOrTi, AdminController.colocarCadeiraEmManutencao);
router.post('/cadeiras/:id/liberar', requireAdminOrTi, AdminController.liberarCadeiraManutencao);
router.get('/cadeiras/:id/historico', requireAdminOrTi, AdminController.getHistoricoCadeira);

export default router;



