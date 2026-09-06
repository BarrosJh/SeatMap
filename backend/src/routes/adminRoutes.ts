import { Router } from 'express';
import { AdminController } from '../controllers/adminController';
import { authenticateToken, requireAdmin, authenticateAdminMfa } from '../middleware/auth';
import { adminLimiter } from '../middleware/rateLimiter';

const router = Router();

// Todas as rotas administrativas exigem autenticação do usuário, rate limit e perfil ADMIN_RH
router.use(adminLimiter);
router.use(authenticateToken);
router.use(requireAdmin);

// 1. Parâmetros e Políticas
router.get('/parametros', AdminController.getParametros);
router.put('/parametros', AdminController.updateParametros);
router.post('/limpeza-noshow', AdminController.executarLimpezaNoShow);
router.get('/relatorio/exportar', AdminController.exportarRelatorioCsv);

// 2. Gestão de Usuários
router.get('/usuarios', AdminController.getUsuarios);
router.post('/usuarios', AdminController.criarUsuario);
router.put('/usuarios/:id', AdminController.updateUsuario);
router.patch('/usuarios/:id/status', AdminController.toggleStatusUsuario);
router.put('/usuarios/:id/status', AdminController.toggleStatusUsuario);
router.post('/usuarios/:id/status', AdminController.toggleStatusUsuario);
router.post('/usuarios/:id/reset-senha', AdminController.resetSenhaUsuario);
router.post('/usuarios/importar-lote', AdminController.importarLoteUsuarios);

// 3. Departamentos
router.get('/departamentos', AdminController.getDepartamentos);
router.post('/departamentos', AdminController.criarDepartamento);

// 4. Gestão Global de Reservas & Cancelamento RH
router.get('/reservas', AdminController.getReservas);
router.post('/reservas/:id/cancelar', AdminController.cancelarReservaAdmin);

export default router;
