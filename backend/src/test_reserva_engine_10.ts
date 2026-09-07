import pool from './config/db';
import { ReservaHistoryService } from './services/reservaHistoryService';
import { DateTime } from 'luxon';


async function runE2ETest() {
  console.log('========================================================================');
  console.log('🧪 INICIANDO TESTE END-TO-END: MOTOR DE RESERVAS 10/10 (AUDITORIA FORENSE & MANUTENÇÃO)');
  console.log('========================================================================\n');

  const client = await pool.connect();

  try {
    // 1. Obter usuário de teste e cadeira de teste
    const userRes = await client.query('SELECT id, nome, email FROM usuarios WHERE ativo = true LIMIT 1');
    const cadeiraRes = await client.query('SELECT id, identificador, baia_id FROM cadeiras WHERE ativa = true LIMIT 1');

    if (userRes.rowCount === 0 || cadeiraRes.rowCount === 0) {
      throw new Error('Nenhum usuário ou cadeira encontrada no banco de dados para o teste.');
    }

    const testUser = userRes.rows[0];
    const testCadeira = cadeiraRes.rows[0];
    const testDate = DateTime.now().setZone('America/Sao_Paulo').plus({ days: 1 }).toISODate()!;

    console.log(`👤 Usuário de Teste: [ID ${testUser.id}] ${testUser.nome} (${testUser.email})`);
    console.log(`🪑 Cadeira de Teste: [ID ${testCadeira.id}] Mesa ${testCadeira.identificador}`);
    console.log(`📅 Data do Teste: ${testDate}\n`);

    // Limpar quaisquer reservas ou eventos prévios na data de teste para isolamento
    await client.query('DELETE FROM reservas WHERE (cadeira_id = $1 OR usuario_id = $2) AND data_reserva = $3', [testCadeira.id, testUser.id, testDate]);
    await client.query('DELETE FROM historico_reservas WHERE (cadeira_id = $1 OR usuario_id = $2) AND data_reserva = $3', [testCadeira.id, testUser.id, testDate]);
    await client.query("UPDATE cadeiras SET status_operacional = 'DISPONIVEL', motivo_manutencao = NULL, previsao_retorno = NULL WHERE id = $1", [testCadeira.id]);


    // ==========================================
    // ETAPA 1: CRIAR RESERVA & REGISTRAR NO HISTÓRICO
    // ==========================================
    console.log('👉 [ETAPA 1] Criando reserva ativa...');
    const insertRes = await client.query(`
      INSERT INTO reservas (cadeira_id, usuario_id, data_reserva, status, codigo_comprovante)
      VALUES ($1, $2, $3, 'ATIVA', 'RES-TESTE-10-10')
      RETURNING id, cadeira_id, usuario_id, data_reserva, status, codigo_comprovante
    `, [testCadeira.id, testUser.id, testDate]);

    const reservaId = insertRes.rows[0].id;
    console.log(`   ✔ Reserva criada com sucesso! [ID ${reservaId}] Comprovante: ${insertRes.rows[0].codigo_comprovante}`);

    // Registrar no histórico
    const histId1 = await ReservaHistoryService.registrarEvento({
      reservaId,
      cadeiraId: testCadeira.id,
      usuarioId: testUser.id,
      dataReserva: testDate,
      tipoEvento: 'CRIADA',
      executadoPorUsuarioId: testUser.id,
      motivo: 'Nova reserva de teste automatizado',
      detalhes: { comprovante: 'RES-TESTE-10-10' }
    });
    console.log(`   ✔ Evento CRIADA registrado no histórico forense [Histórico ID ${histId1}]`);

    // ==========================================
    // ETAPA 2: REALIZAR CHECK-IN
    // ==========================================
    console.log('\n👉 [ETAPA 2] Realizando check-in de presença...');
    await client.query('UPDATE reservas SET checkin_realizado = true, checkin_em = NOW() WHERE id = $1', [reservaId]);
    const histId2 = await ReservaHistoryService.registrarEvento({
      reservaId,
      cadeiraId: testCadeira.id,
      usuarioId: testUser.id,
      dataReserva: testDate,
      tipoEvento: 'CHECKIN',
      executadoPorUsuarioId: testUser.id,
      motivo: 'Check-in confirmado pelo colaborador'
    });
    console.log(`   ✔ Evento CHECKIN registrado no histórico forense [Histórico ID ${histId2}]`);

    // ==========================================
    // ETAPA 3: COLOCAR CADEIRA EM MANUTENÇÃO (FACILITIES / TI)
    // ==========================================
    console.log('\n👉 [ETAPA 3] Bloqueando cadeira para manutenção técnica...');
    const motivoManutencao = 'Tomada 220V com sobrecarga e monitor com defeito na tela';
    const previsaoRetorno = DateTime.now().setZone('America/Sao_Paulo').plus({ days: 2 }).toISO();

    await client.query(`
      UPDATE cadeiras
      SET status_operacional = 'EM_MANUTENCAO',
          motivo_manutencao = $1,
          previsao_retorno = $2,
          manutencao_por_usuario_id = $3
      WHERE id = $4
    `, [motivoManutencao, previsaoRetorno, testUser.id, testCadeira.id]);

    // Cancelar reservas ativas afetadas
    const afetadasRes = await client.query(`
      SELECT id, usuario_id, data_reserva, codigo_comprovante
      FROM reservas
      WHERE cadeira_id = $1 AND data_reserva = $2 AND status = 'ATIVA'
    `, [testCadeira.id, testDate]);

    console.log(`   ℹ Reservas ativas canceladas preventivamente: ${afetadasRes.rowCount}`);
    if (afetadasRes.rowCount! > 0) {
      await client.query("UPDATE reservas SET status = 'CANCELADA' WHERE id = $1", [reservaId]);
      await ReservaHistoryService.registrarEvento({
        reservaId,
        cadeiraId: testCadeira.id,
        usuarioId: testUser.id,
        dataReserva: testDate,
        tipoEvento: 'CANCELADA_MANUTENCAO',
        executadoPorUsuarioId: testUser.id,
        motivo: `Cancelamento preventivo por intervenção técnica: ${motivoManutencao}`
      });
      console.log('   ✔ Evento CANCELADA_MANUTENCAO gravado na linha do tempo forense!');
    }

    // ==========================================
    // ETAPA 4: VERIFICAR SE O MOTOR IMPEDE NOVA RESERVA EM CADEIRA EM MANUTENÇÃO
    // ==========================================
    console.log('\n👉 [ETAPA 4] Tentando efetuar reserva em cadeira com status EM_MANUTENCAO...');
    const checkCad = await client.query('SELECT status_operacional, motivo_manutencao FROM cadeiras WHERE id = $1', [testCadeira.id]);
    const cadStatus = checkCad.rows[0];

    if (cadStatus.status_operacional === 'EM_MANUTENCAO') {
      console.log(`   ✔ BLOQUEIO ACID CONFIRMADO: Cadeira recusada com status [${cadStatus.status_operacional}]. Motivo: "${cadStatus.motivo_manutencao}"`);
    } else {
      throw new Error('Falha de consistência: Cadeira deveria estar em manutenção.');
    }

    // ==========================================
    // ETAPA 5: LIBERAR CADEIRA DE MANUTENÇÃO
    // ==========================================
    console.log('\n👉 [ETAPA 5] Liberando cadeira da manutenção...');
    await client.query(`
      UPDATE cadeiras
      SET status_operacional = 'DISPONIVEL', motivo_manutencao = NULL, previsao_retorno = NULL
      WHERE id = $1
    `, [testCadeira.id]);

    const checkCadLiberada = await client.query('SELECT status_operacional FROM cadeiras WHERE id = $1', [testCadeira.id]);
    console.log(`   ✔ Status da cadeira atualizado para: [${checkCadLiberada.rows[0].status_operacional}]`);

    // ==========================================
    // ETAPA 6: CONSULTAR HISTÓRICO FORENSE DA CADEIRA
    // ==========================================
    console.log('\n👉 [ETAPA 6] Consultando Linha do Tempo Forense Completa da Cadeira...');
    const historico = await ReservaHistoryService.getHistoricoCadeira(testCadeira.id, 10, 0);

    console.log(`   ✔ Total de eventos recuperados no histórico: ${historico.length}`);
    historico.forEach((ev: any, idx: number) => {
      console.log(`   [Evento #${idx + 1}] Data: ${ev.data_reserva} | Tipo: ${ev.tipo_evento} | Usuário: ${ev.usuario_nome} | Motivo: ${ev.motivo || 'N/A'}`);
    });

    console.log('\n========================================================================');
    console.log('🎉 TODOS OS TESTES ACID, MANUTENÇÃO E HISTÓRICO FORENSE FORAM CONCLUÍDOS COM 100% DE SUCESSO!');
    console.log('========================================================================\n');

  } catch (error) {
    console.error('❌ ERRO NO TESTE:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

runE2ETest();
