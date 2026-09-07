import { Response } from 'express';
import { AuthenticatedRequest } from '../middleware/auth';
import { AdminParametrosController } from './admin/adminParametrosController';
import { AdminUsuariosController } from './admin/adminUsuariosController';
import { AdminDepartamentosController } from './admin/adminDepartamentosController';
import { AdminReservasController } from './admin/adminReservasController';
import { FacilitiesController } from './admin/facilitiesController';

export { AdminParametrosController } from './admin/adminParametrosController';
export { AdminUsuariosController } from './admin/adminUsuariosController';
export { AdminDepartamentosController } from './admin/adminDepartamentosController';
export { AdminReservasController } from './admin/adminReservasController';
export { FacilitiesController } from './admin/facilitiesController';

export class AdminController {
  // 1. Configurações & Parâmetros
  public static getParametros(req: AuthenticatedRequest, res: Response) {
    return AdminParametrosController.getParametros(req, res);
  }

  public static updateParametros(req: AuthenticatedRequest, res: Response) {
    return AdminParametrosController.updateParametros(req, res);
  }

  public static executarLimpezaNoShow(req: AuthenticatedRequest, res: Response) {
    return AdminParametrosController.executarLimpezaNoShow(req, res);
  }

  public static exportarRelatorioCsv(req: AuthenticatedRequest, res: Response) {
    return AdminParametrosController.exportarRelatorioCsv(req, res);
  }

  // 2. Gestão de Usuários
  public static getUsuarios(req: AuthenticatedRequest, res: Response) {
    return AdminUsuariosController.getUsuarios(req, res);
  }

  public static criarUsuario(req: AuthenticatedRequest, res: Response) {
    return AdminUsuariosController.criarUsuario(req, res);
  }

  public static updateUsuario(req: AuthenticatedRequest, res: Response) {
    return AdminUsuariosController.updateUsuario(req, res);
  }

  public static toggleStatusUsuario(req: AuthenticatedRequest, res: Response) {
    return AdminUsuariosController.toggleStatusUsuario(req, res);
  }

  public static resetSenhaUsuario(req: AuthenticatedRequest, res: Response) {
    return AdminUsuariosController.resetSenhaUsuario(req, res);
  }

  public static importarLoteUsuarios(req: AuthenticatedRequest, res: Response) {
    return AdminUsuariosController.importarLoteUsuarios(req, res);
  }

  // 3. Gestão de Departamentos
  public static getDepartamentos(req: AuthenticatedRequest, res: Response) {
    return AdminDepartamentosController.getDepartamentos(req, res);
  }

  public static criarDepartamento(req: AuthenticatedRequest, res: Response) {
    return AdminDepartamentosController.criarDepartamento(req, res);
  }

  // 4. Gestão Global de Reservas
  public static getReservas(req: AuthenticatedRequest, res: Response) {
    return AdminReservasController.getReservas(req, res);
  }

  public static cancelarReservaAdmin(req: AuthenticatedRequest, res: Response) {
    return AdminReservasController.cancelarReservaAdmin(req, res);
  }

  // 5. Facilities & Manutenção de Assentos
  public static colocarCadeiraEmManutencao(req: AuthenticatedRequest, res: Response) {
    return FacilitiesController.colocarCadeiraEmManutencao(req, res);
  }

  public static liberarCadeiraManutencao(req: AuthenticatedRequest, res: Response) {
    return FacilitiesController.liberarCadeiraManutencao(req, res);
  }

  public static getHistoricoCadeira(req: AuthenticatedRequest, res: Response) {
    return FacilitiesController.getHistoricoCadeira(req, res);
  }

  public static getCadeirasManutencao(req: AuthenticatedRequest, res: Response) {
    return FacilitiesController.getCadeirasManutencao(req, res);
  }

  public static getTodasCadeiras(req: AuthenticatedRequest, res: Response) {
    return FacilitiesController.getTodasCadeiras(req, res);
  }
}
