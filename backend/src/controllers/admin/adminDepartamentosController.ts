import { Response } from 'express';
import pool from '../../config/db';
import { AuthenticatedRequest } from '../../middleware/auth';

export class AdminDepartamentosController {
  public static async getDepartamentos(req: AuthenticatedRequest, res: Response) {
    try {
      const result = await pool.query(`
        SELECT 
          d.id,
          d.nome,
          COUNT(u.id) AS total_usuarios
        FROM departamentos d
        LEFT JOIN usuarios u ON u.departamento_id = d.id
        GROUP BY d.id, d.nome
        ORDER BY d.nome ASC
      `);

      return res.status(200).json(result.rows);
    } catch (error) {
      console.error('[AdminDepartamentosController.getDepartamentos] Erro:', error);
      return res.status(500).json({ error: 'Erro ao listar departamentos.' });
    }
  }

  public static async criarDepartamento(req: AuthenticatedRequest, res: Response) {
    try {
      const { nome } = req.body;
      if (!nome || typeof nome !== 'string' || nome.trim().length === 0) {
        return res.status(400).json({ error: 'O nome do departamento é obrigatório.' });
      }

      const result = await pool.query(`
        INSERT INTO departamentos (nome)
        VALUES ($1)
        ON CONFLICT (nome) DO NOTHING
        RETURNING id, nome
      `, [nome.trim()]);

      if (result.rowCount === 0) {
        return res.status(400).json({ error: 'Já existe um departamento com este nome.' });
      }

      return res.status(201).json({
        message: 'Departamento criado com sucesso.',
        departamento: result.rows[0]
      });
    } catch (error) {
      console.error('[AdminDepartamentosController.criarDepartamento] Erro:', error);
      return res.status(500).json({ error: 'Erro ao criar departamento.' });
    }
  }
}
