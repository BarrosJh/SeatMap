import bcrypt from 'bcrypt';
import pool from '../config/db';

async function runSeed() {
  const client = await pool.connect();
  try {
    console.log('[Seed] Iniciando população dos mapas Barueri e Berrini...');
    await client.query('BEGIN');

    // 1. Limpar dados existentes
    await client.query('TRUNCATE TABLE auth_mfa_codes, reservas, cadeiras, baias, usuarios, departamentos, escritorios, configuracoes_sistema RESTART IDENTITY CASCADE');

    // 2. Inserir Escritórios (Barueri e Berrini)
    const resEscritorios = await client.query(`
      INSERT INTO escritorios (nome, cidade, ativo) VALUES
      ('Barueri', 'Barueri', true),
      ('Berrini', 'São Paulo', true)
      RETURNING id, nome;
    `);
    const barueriId = resEscritorios.rows[0].id;
    const berriniId = resEscritorios.rows[1].id;
    console.log(`[Seed] Inseridos escritórios: Barueri (id: ${barueriId}) e Berrini (id: ${berriniId}).`);

    // 3. Inserir Departamentos
    const resDeptos = await client.query(`
      INSERT INTO departamentos (nome) VALUES
      ('Jurídico'),
      ('TI & Engenharia'),
      ('Operações'),
      ('Recursos Humanos')
      RETURNING id, nome;
    `);
    const juridicoId = resDeptos.rows[0].id;
    const tiId = resDeptos.rows[1].id;
    const operacoesId = resDeptos.rows[2].id;
    const rhId = resDeptos.rows[3].id;
    console.log(`[Seed] Inseridos ${resDeptos.rowCount} departamentos.`);

    // 4. Inserir Usuários de Teste
    const defaultPasswordHash = await bcrypt.hash('123456', 10);
    const resUsers = await client.query(`
      INSERT INTO usuarios (nome, email, matricula, senha_hash, departamento_id, perfil, ativo) VALUES
      ('Carlos Silva', 'colaborador@seatmap.local', 'COLAB001', $1, $2, 'COLABORADOR', true),
      ('Mariana Costa', 'gestao@seatmap.local', 'GEST001', $1, $3, 'GESTAO', true),
      ('Fernanda Lima', 'admin@seatmap.local', 'ADMIN001', $1, $4, 'ADMIN_RH', true),
      ('Lucas Mendes', 'lucas.ti@seatmap.local', 'COLAB002', $1, $2, 'COLABORADOR', true),
      ('Beatriz Rocha', 'beatriz.jur@seatmap.local', 'COLAB003', $1, $5, 'COLABORADOR', true)
      RETURNING id, nome, email, perfil;
    `, [defaultPasswordHash, tiId, operacoesId, rhId, juridicoId]);
    console.log(`[Seed] Inseridos ${resUsers.rowCount} usuários de teste.`);

    // 5. Inserir Bancadas/Baias Reais para Barueri
    const barueriBenches = [
      { nome: 'Bancada 01', seatIds: [1, 2, 3, 4] },
      { nome: 'Bancada 02', seatIds: [5, 6, 7, 8, 9, 10, 11, 12] },
      { nome: 'Bancada 03', seatIds: [13, 14, 15, 16, 17, 18, 19, 20] },
      { nome: 'Bancada 04', seatIds: [21, 22, 23, 24, 25, 26] },
      { nome: 'Bancada 05', seatIds: [27, 28, 29, 30, 31, 32, 33, 34, 35, 36] },
      { nome: 'Bancada 06', seatIds: [37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50] },
      { nome: 'Bancada 07', seatIds: [51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66] }
    ];

    const seatToBaiaBarueri: Record<number, number> = {};
    for (const bench of barueriBenches) {
      const resBaia = await client.query(
        'INSERT INTO baias (escritorio_id, nome) VALUES ($1, $2) RETURNING id',
        [barueriId, bench.nome]
      );
      const baiaId = resBaia.rows[0].id;
      for (const sId of bench.seatIds) {
        seatToBaiaBarueri[sId] = baiaId;
      }
    }
    console.log(`[Seed] Inseridas ${barueriBenches.length} bancadas reais para Barueri.`);

    // 6. Inserir Bancadas/Baias Reais para Berrini (15 Bancadas)
    const berriniBenches = [
      { nome: 'Bancada 01', seatIds: [1, 2, 3, 4, 5, 6, 7, 8] },
      { nome: 'Bancada 02', seatIds: [9, 10, 11, 12, 13, 14, 15, 16] },
      { nome: 'Bancada 03', seatIds: [17, 18, 19, 20, 21, 22] },
      { nome: 'Bancada 04', seatIds: [23, 24, 25, 26, 27, 28] },
      { nome: 'Bancada 05', seatIds: [29, 30, 31, 32, 33, 34] },
      { nome: 'Bancada 06', seatIds: [35, 36, 37, 38, 39, 40] },
      { nome: 'Bancada 07', seatIds: [41, 42, 43, 44, 45, 46] },
      { nome: 'Bancada 08', seatIds: [47, 48, 49, 50, 51, 52] },
      { nome: 'Bancada 09', seatIds: [53, 54, 55, 56, 57, 58, 59, 60] },
      { nome: 'Bancada 10', seatIds: [61, 62, 63, 64, 65, 66, 67, 68] },
      { nome: 'Bancada 11', seatIds: [69, 70, 71, 72, 73, 74, 75, 76] },
      { nome: 'Bancada 12', seatIds: [77, 78, 79, 80, 81, 82, 83, 84] },
      { nome: 'Bancada 13', seatIds: [85, 86, 87, 88, 89, 90] },
      { nome: 'Bancada 14', seatIds: [91, 92, 93, 94, 95, 96] },
      { nome: 'Bancada 15', seatIds: [97, 98, 99, 100, 101, 102] }
    ];

    const seatToBaiaBerrini: Record<number, number> = {};
    for (const bench of berriniBenches) {
      const resBaia = await client.query(
        'INSERT INTO baias (escritorio_id, nome) VALUES ($1, $2) RETURNING id',
        [berriniId, bench.nome]
      );
      const baiaId = resBaia.rows[0].id;
      for (const sId of bench.seatIds) {
        seatToBaiaBerrini[sId] = baiaId;
      }
    }
    console.log(`[Seed] Inseridas ${berriniBenches.length} bancadas reais para Berrini.`);

    // 7. Cadastrar 66 CADEIRAS DE BARUERI (Coordenadas fiéis à planta de Barueri)
    const barueriSeats: Array<{ id: number; x: number; y: number }> = [
      { id: 1, x: 118, y: 591 },
      { id: 2, x: 118, y: 548 },
      { id: 3, x: 141, y: 591 },
      { id: 4, x: 141, y: 548 },
      { id: 5, x: 262, y: 604 },
      { id: 6, x: 262, y: 561 },
      { id: 7, x: 238, y: 515 },
      { id: 8, x: 204, y: 482 },
      { id: 9, x: 285, y: 604 },
      { id: 10, x: 285, y: 561 },
      { id: 11, x: 255, y: 498 },
      { id: 12, x: 222, y: 465 },
      { id: 13, x: 388, y: 510 },
      { id: 14, x: 356, y: 478 },
      { id: 15, x: 324, y: 446 },
      { id: 16, x: 292, y: 415 },
      { id: 17, x: 404, y: 494 },
      { id: 18, x: 372, y: 462 },
      { id: 19, x: 340, y: 431 },
      { id: 20, x: 308, y: 399 },
      { id: 21, x: 480, y: 439 },
      { id: 22, x: 448, y: 407 },
      { id: 23, x: 417, y: 375 },
      { id: 24, x: 497, y: 422 },
      { id: 25, x: 465, y: 391 },
      { id: 26, x: 432, y: 359 },
      { id: 27, x: 575, y: 330 },
      { id: 28, x: 543, y: 298 },
      { id: 29, x: 480, y: 284 },
      { id: 30, x: 430, y: 284 },
      { id: 31, x: 379, y: 284 },
      { id: 32, x: 591, y: 314 },
      { id: 33, x: 559, y: 282 },
      { id: 34, x: 479, y: 259 },
      { id: 35, x: 429, y: 259 },
      { id: 36, x: 379, y: 259 },
      { id: 37, x: 658, y: 260 },
      { id: 38, x: 627, y: 229 },
      { id: 39, x: 595, y: 197 },
      { id: 40, x: 532, y: 186 },
      { id: 41, x: 481, y: 186 },
      { id: 42, x: 430, y: 186 },
      { id: 43, x: 379, y: 186 },
      { id: 44, x: 675, y: 244 },
      { id: 45, x: 643, y: 212 },
      { id: 46, x: 610, y: 181 },
      { id: 47, x: 531, y: 161 },
      { id: 48, x: 480, y: 161 },
      { id: 49, x: 429, y: 161 },
      { id: 50, x: 379, y: 161 },
      { id: 51, x: 711, y: 160 },
      { id: 52, x: 679, y: 128 },
      { id: 53, x: 647, y: 96 },
      { id: 54, x: 583, y: 83 },
      { id: 55, x: 532, y: 83 },
      { id: 56, x: 481, y: 83 },
      { id: 57, x: 430, y: 83 },
      { id: 58, x: 379, y: 83 },
      { id: 59, x: 727, y: 144 },
      { id: 60, x: 695, y: 112 },
      { id: 61, x: 663, y: 81 },
      { id: 62, x: 582, y: 58 },
      { id: 63, x: 531, y: 58 },
      { id: 64, x: 480, y: 58 },
      { id: 65, x: 429, y: 58 },
      { id: 66, x: 379, y: 58 }
    ];

    for (const seat of barueriSeats) {
      const bId = seatToBaiaBarueri[seat.id] || Object.values(seatToBaiaBarueri)[0];
      await client.query(`
        INSERT INTO cadeiras (baia_id, identificador, posicao_x, posicao_y, ativa)
        VALUES ($1, $2, $3, $4, true);
      `, [bId, seat.id.toString(), seat.x, seat.y]);
    }
    console.log(`[Seed] Inseridas 66 cadeiras para Barueri distribuídas em suas respectivas bancadas.`);

    // 8. Cadastrar 102 CADEIRAS DE BERRINI (Coordenadas fiéis à planta de Berrini)
    const berriniSeats: Array<{ id: number; x: number; y: number }> = [
      { id: 1, x: 12, y: 333 },
      { id: 2, x: 55, y: 332 },
      { id: 3, x: 98, y: 332 },
      { id: 4, x: 141, y: 332 },
      { id: 5, x: 141, y: 309 },
      { id: 6, x: 98, y: 309 },
      { id: 7, x: 55, y: 309 },
      { id: 8, x: 12, y: 309 },
      { id: 9, x: 12, y: 237 },
      { id: 10, x: 55, y: 237 },
      { id: 11, x: 98, y: 237 },
      { id: 12, x: 141, y: 237 },
      { id: 13, x: 141, y: 214 },
      { id: 14, x: 98, y: 214 },
      { id: 15, x: 55, y: 214 },
      { id: 16, x: 12, y: 214 },
      { id: 17, x: 308, y: 300 },
      { id: 18, x: 308, y: 261 },
      { id: 19, x: 308, y: 222 },
      { id: 20, x: 334, y: 300 },
      { id: 21, x: 334, y: 261 },
      { id: 22, x: 334, y: 222 },
      { id: 23, x: 417, y: 300 },
      { id: 24, x: 417, y: 261 },
      { id: 25, x: 417, y: 222 },
      { id: 26, x: 443, y: 300 },
      { id: 27, x: 443, y: 261 },
      { id: 28, x: 443, y: 222 },
      { id: 29, x: 526, y: 300 },
      { id: 30, x: 526, y: 261 },
      { id: 31, x: 526, y: 222 },
      { id: 32, x: 552, y: 300 },
      { id: 33, x: 552, y: 261 },
      { id: 34, x: 552, y: 222 },
      { id: 35, x: 635, y: 300 },
      { id: 36, x: 635, y: 261 },
      { id: 37, x: 635, y: 222 },
      { id: 38, x: 661, y: 300 },
      { id: 39, x: 661, y: 261 },
      { id: 40, x: 661, y: 222 },
      { id: 41, x: 744, y: 300 },
      { id: 42, x: 744, y: 261 },
      { id: 43, x: 744, y: 222 },
      { id: 44, x: 770, y: 300 },
      { id: 45, x: 770, y: 261 },
      { id: 46, x: 770, y: 222 },
      { id: 47, x: 853, y: 300 },
      { id: 48, x: 853, y: 261 },
      { id: 49, x: 853, y: 222 },
      { id: 50, x: 879, y: 300 },
      { id: 51, x: 879, y: 261 },
      { id: 52, x: 879, y: 222 },
      { id: 53, x: 470, y: 142 },
      { id: 54, x: 470, y: 103 },
      { id: 55, x: 470, y: 64 },
      { id: 56, x: 470, y: 25 },
      { id: 57, x: 496, y: 142 },
      { id: 58, x: 496, y: 103 },
      { id: 59, x: 496, y: 64 },
      { id: 60, x: 496, y: 25 },
      { id: 61, x: 579, y: 142 },
      { id: 62, x: 579, y: 103 },
      { id: 63, x: 579, y: 64 },
      { id: 64, x: 579, y: 25 },
      { id: 65, x: 605, y: 142 },
      { id: 66, x: 605, y: 103 },
      { id: 67, x: 605, y: 64 },
      { id: 68, x: 605, y: 25 },
      { id: 69, x: 688, y: 142 },
      { id: 70, x: 688, y: 103 },
      { id: 71, x: 688, y: 64 },
      { id: 72, x: 688, y: 25 },
      { id: 73, x: 714, y: 142 },
      { id: 74, x: 714, y: 103 },
      { id: 75, x: 714, y: 64 },
      { id: 76, x: 714, y: 25 },
      { id: 77, x: 797, y: 142 },
      { id: 78, x: 797, y: 103 },
      { id: 79, x: 797, y: 64 },
      { id: 80, x: 797, y: 25 },
      { id: 81, x: 823, y: 142 },
      { id: 82, x: 823, y: 103 },
      { id: 83, x: 823, y: 64 },
      { id: 84, x: 823, y: 25 },
      { id: 85, x: 576, y: 458 },
      { id: 86, x: 576, y: 419 },
      { id: 87, x: 576, y: 380 },
      { id: 88, x: 602, y: 458 },
      { id: 89, x: 602, y: 419 },
      { id: 90, x: 602, y: 380 },
      { id: 91, x: 685, y: 458 },
      { id: 92, x: 685, y: 419 },
      { id: 93, x: 685, y: 380 },
      { id: 94, x: 711, y: 458 },
      { id: 95, x: 711, y: 419 },
      { id: 96, x: 711, y: 380 },
      { id: 97, x: 794, y: 458 },
      { id: 98, x: 794, y: 419 },
      { id: 99, x: 794, y: 380 },
      { id: 100, x: 820, y: 458 },
      { id: 101, x: 820, y: 419 },
      { id: 102, x: 820, y: 380 }
    ];

    for (const seat of berriniSeats) {
      const bId = seatToBaiaBerrini[seat.id] || Object.values(seatToBaiaBerrini)[0];
      await client.query(`
        INSERT INTO cadeiras (baia_id, identificador, posicao_x, posicao_y, ativa)
        VALUES ($1, $2, $3, $4, true);
      `, [bId, seat.id.toString(), seat.x, seat.y]);
    }
    console.log(`[Seed] Inseridas 102 cadeiras para Berrini distribuídas em suas 15 bancadas reais.`);

    // 8. Inserir Parâmetros padrão do Sistema
    await client.query(`
      INSERT INTO configuracoes_sistema (chave, valor, descricao) VALUES
      ('LIMITE_SEMANAL_RESERVAS', '2', 'Quantidade máxima de reservas permitidas por semana para cada colaborador'),
      ('HORARIO_ABERTURA_GESTAO', '08:00', 'Horário de liberação da agenda da próxima semana para perfil GESTAO'),
      ('DIA_ABERTURA_GESTAO', '5', 'Dia da semana para abertura GESTAO (1=Segunda a 7=Domingo)'),
      ('HORARIO_ABERTURA_COLABORADOR', '12:00', 'Horário de liberação da agenda da próxima semana para perfil COLABORADOR'),
      ('DIA_ABERTURA_COLABORADOR', '5', 'Dia da semana para abertura COLABORADOR (1=Segunda a 7=Domingo)'),
      ('HORARIO_INICIO_CHECKIN', '06:00', 'Horário a partir do qual a confirmação diária de presença é liberada'),
      ('HORARIO_LIMITE_CHECKIN', '11:00', 'Horário de corte para confirmação diária de presença no app'),
      ('PERMITIR_TROCA_MESMO_DIA', 'true', 'Permite que o colaborador troque de assento para a mesma data já reservada'),
      ('CHECKIN_AUTOMATICO_GESTAO', 'true', 'Realiza o check-in automático ao reservar para usuários com perfil GESTAO'),
      ('AVISO_GLOBAL_SISTEMA', '', 'Mensagem institucional de aviso em tempo real exibida no topo do app'),
      ('MFA_EXPIRACAO_MINUTOS', '10', 'Tempo de validade do código MFA enviado por e-mail (em minutos)'),
      ('MFA_MAX_TENTATIVAS', '3', 'Quantidade máxima de tentativas inválidas de MFA antes de bloquear o código'),
      ('TIMEZONE', 'America/Sao_Paulo', 'Fuso horário oficial do sistema')
      ON CONFLICT (chave) DO UPDATE SET valor = EXCLUDED.valor, descricao = EXCLUDED.descricao;
    `);

    await client.query('COMMIT');
    console.log('[Seed] Plantas de Barueri e Berrini populadas com sucesso!');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('[Seed] Erro durante a carga:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

if (require.main === module) {
  runSeed();
}

export default runSeed;
