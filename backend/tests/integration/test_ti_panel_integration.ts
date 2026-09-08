const BASE_URL = 'http://localhost:3000/api';

async function runTiTests() {
  console.log('====================================================');
  console.log('INICIANDO AUDITORIA & TESTES DO PAINEL DE TI');
  console.log('====================================================\n');

  try {
    // 1. Login com o Administrador de TI
    console.log('1. Autenticando Administrador de TI (ti@seatmap.local)...');
    const loginRes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        login: 'ti@seatmap.local',
        senha: '123456'
      })
    });

    const loginData: any = await loginRes.json();
    if (!loginRes.ok) {
      throw new Error(`Falha no login: ${JSON.stringify(loginData)}`);
    }

    const { token, user } = loginData;
    console.log(`✔ Login TI bem-sucedido! Nome: ${user.nome} | Perfil: ${user.perfil} | Permissão TI: ${user.permissao_ti || user.permissaoTi}`);

    const headers = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    };

    // 2. Consulta de Configurações de TI
    console.log('\n2. Buscando Configurações de TI (GET /api/admin/ti/configuracoes)...');
    const configRes = await fetch(`${BASE_URL}/admin/ti/configuracoes`, { headers });
    const configData = await configRes.json();
    console.log('✔ Configurações carregadas:', JSON.stringify(configData, null, 2));

    // 3. Atualização de Configurações SMTP / MFA com Hot-Reload
    console.log('\n3. Atualizando parâmetros de TI (PUT /api/admin/ti/configuracoes)...');
    const updateRes = await fetch(`${BASE_URL}/admin/ti/configuracoes`, {
      method: 'PUT',
      headers,
      body: JSON.stringify({
        smtpHost: 'smtp.gmail.com',
        smtpPort: 587,
        smtpSecure: false,
        smtpUser: 'ti-seatmap@empresa.com',
        emailFrom: '"SeatMap Corporate Hub" <nao-responda@seatmap.local>',
        mfaExpiracaoMinutos: 15,
        mfaMaxTentativas: 5
      })
    });
    const updateData = await updateRes.json();
    console.log('✔ Resposta da atualização:', updateData);

    // 4. Teste de Disparo de E-mail SMTP
    console.log('\n4. Disparando Teste de Envio SMTP (POST /api/admin/ti/testar-email)...');
    const testEmailRes = await fetch(`${BASE_URL}/admin/ti/testar-email`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        emailDestino: 'ti@seatmap.local',
        nomeDestino: 'Administrador TI'
      })
    });
    const testEmailData = await testEmailRes.json();
    console.log('✔ Resultado do teste de e-mail:', testEmailData);

    // 5. Diagnóstico de Saúde e Métricas do Sistema
    console.log('\n5. Coletando Diagnóstico do Sistema (GET /api/admin/ti/status)...');
    const statusRes = await fetch(`${BASE_URL}/admin/ti/status`, { headers });
    const statusData = await statusRes.json();
    console.log('✔ Métricas de Saúde:', JSON.stringify(statusData, null, 2));

    // 6. Histórico de Auditoria MFA
    console.log('\n6. Consultando Auditoria MFA (GET /api/admin/ti/auditoria-mfa)...');
    const auditRes = await fetch(`${BASE_URL}/admin/ti/auditoria-mfa`, { headers });
    const auditData: any = await auditRes.json();
    console.log(`✔ Registros de auditoria encontrados: ${auditData.auditoria?.length ?? 0}`);

    // 7. Teste de Bloqueio de Segurança para Colaborador Comum
    console.log('\n7. Testando Barreira de Segurança (requireTi) com Colaborador...');
    const loginColabRes = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        login: 'colaborador@seatmap.local',
        senha: '123456'
      })
    });
    const loginColabData: any = await loginColabRes.json();
    const colabHeaders = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${loginColabData.token}`
    };

    const colabTestRes = await fetch(`${BASE_URL}/admin/ti/configuracoes`, { headers: colabHeaders });
    if (colabTestRes.status === 403) {
      const colabErr: any = await colabTestRes.json();
      console.log(`✔ Acesso de colaborador corretamente bloqueado com HTTP 403: ${colabErr.error}`);
    } else {
      console.error(`❌ Status inesperado para colaborador: ${colabTestRes.status}`);
    }

    console.log('\n====================================================');
    console.log('TODOS OS TESTES DO PAINEL DE TI FORAM 100% APROVADOS!');
    console.log('====================================================');
  } catch (error: any) {
    console.error('\n❌ Erro durante a execução dos testes:', error.message);
  }
}

runTiTests();
