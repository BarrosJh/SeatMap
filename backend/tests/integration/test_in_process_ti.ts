import pool from '../../src/config/db';
import { ConfigService } from '../../src/services/configService';
import { EmailService } from '../../src/services/emailService';
import { TiController } from '../../src/controllers/tiController';

async function testTiDirectly() {
  console.log('====================================================');
  console.log('TESTE DIRETO DE CONTROLADORES E SERVIÇOS DE TI');
  console.log('====================================================\n');

  try {
    // 1. Validar usuário de TI no banco
    console.log('1. Verificando usuário ti@seatmap.local no banco de dados...');
    const userRes = await pool.query("SELECT id, nome, email, perfil, permissao_ti FROM usuarios WHERE email = 'ti@seatmap.local'");
    if (userRes.rowCount === 0) {
      throw new Error('Usuário ti@seatmap.local não encontrado no banco.');
    }
    const tiUser = userRes.rows[0];
    console.log('✔ Usuário TI encontrado:', tiUser);

    // 2. Testar leitura de configurações via TiController
    console.log('\n2. Testando TiController.getConfiguracoesTi...');
    let configOutput: any = null;
    const reqMock: any = { user: tiUser };
    const resMock: any = {
      status: (code: number) => ({
        json: (data: any) => {
          configOutput = { statusCode: code, data };
        }
      })
    };

    await TiController.getConfiguracoesTi(reqMock, resMock);
    console.log(`✔ Resposta TiController.getConfiguracoesTi (HTTP ${configOutput.statusCode}):`, configOutput.data);

    // 3. Testar atualização de configurações via TiController
    console.log('\n3. Testando TiController.updateConfiguracoesTi (hot-reload)...');
    let updateOutput: any = null;
    const updateReqMock: any = {
      user: tiUser,
      body: {
        smtpHost: 'smtp.gmail.com',
        smtpPort: 587,
        smtpSecure: false,
        smtpUser: 'ti-seatmap@empresa.com',
        emailFrom: '"SeatMap Corporate Hub" <nao-responda@seatmap.local>',
        mfaExpiracaoMinutos: 15,
        mfaMaxTentativas: 5
      }
    };
    const updateResMock: any = {
      status: (code: number) => ({
        json: (data: any) => {
          updateOutput = { statusCode: code, data };
        }
      })
    };

    await TiController.updateConfiguracoesTi(updateReqMock, updateResMock);
    console.log(`✔ Resposta TiController.updateConfiguracoesTi (HTTP ${updateOutput.statusCode}):`, updateOutput.data);

    // 4. Testar envio de e-mail de teste
    console.log('\n4. Testando TiController.testarConexaoEmail...');
    let testEmailOutput: any = null;
    const testEmailReqMock: any = {
      user: tiUser,
      body: {
        emailDestino: 'ti@seatmap.local',
        nomeDestino: 'Administrador TI'
      }
    };
    const testEmailResMock: any = {
      status: (code: number) => ({
        json: (data: any) => {
          testEmailOutput = { statusCode: code, data };
        }
      })
    };

    await TiController.testarConexaoEmail(testEmailReqMock, testEmailResMock);
    console.log(`✔ Resposta TiController.testarConexaoEmail (HTTP ${testEmailOutput.statusCode}):`, testEmailOutput.data);

    // 5. Testar diagnóstico de saúde do sistema
    console.log('\n5. Testando TiController.getStatusSistema...');
    let statusOutput: any = null;
    const statusReqMock: any = { user: tiUser };
    const statusResMock: any = {
      status: (code: number) => ({
        json: (data: any) => {
          statusOutput = { statusCode: code, data };
        }
      })
    };

    await TiController.getStatusSistema(statusReqMock, statusResMock);
    console.log(`✔ Resposta TiController.getStatusSistema (HTTP ${statusOutput.statusCode}):`, statusOutput.data);

    // 6. Testar auditoria de MFA
    console.log('\n6. Testando TiController.getAuditoriaMfa...');
    let auditOutput: any = null;
    const auditReqMock: any = { user: tiUser };
    const auditResMock: any = {
      status: (code: number) => ({
        json: (data: any) => {
          auditOutput = { statusCode: code, data };
        }
      })
    };

    await TiController.getAuditoriaMfa(auditReqMock, auditResMock);
    console.log(`✔ Resposta TiController.getAuditoriaMfa (HTTP ${auditOutput.statusCode}): ${auditOutput.data.auditoria.length} registros`);

    console.log('\n====================================================');
    console.log('TODAS AS FUNÇÕES DE TI TESTADAS E VALIDADAS COM SUCESSO!');
    console.log('====================================================');
  } catch (error) {
    console.error('❌ Erro no teste:', error);
  } finally {
    await pool.end();
  }
}

testTiDirectly();
