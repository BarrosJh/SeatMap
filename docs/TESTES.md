# Estratégia e Execução de Testes (SeatMap)

Este documento descreve as suítes de testes automatizados do sistema e os comandos para execução local e em pipeline.

---

## 1. Backend (Node.js / TypeScript / Jest)

Os testes automatizados cobrem regras de negócio, atomicidade de transações, validação de esquemas Zod, rate limiting e serviços de segurança (MFA, JWT, criptografia AES-256-GCM).

* **Unitários e Isolados:** [`backend/tests/unit/`](../backend/tests/unit/)
* **Integração e Contrato:** [`backend/tests/integration/`](../backend/tests/integration/)

### Comandos de Execução:
```bash
# Executar todos os testes com relatório
cd backend
npm test

# Executar com cobertura de código (Coverage)
npm run test:coverage

# Executar apenas uma suíte específica (ex.: reservas)
npx jest tests/unit/reservasService.test.ts
```

---

## 2. Frontend (Flutter / Dart)

Os testes de frontend cobrem controllers, gerenciamento de estado (MobX), integração com o cofre seguro (`FlutterSecureStorage`) e renderização de componentes de interface.

* **Diretório:** [`frontend/test/`](../frontend/test/)

### Comandos de Execução:
```bash
# Executar análise estática de tipos e linters
cd frontend
flutter analyze

# Executar todos os testes do Flutter
flutter test
```

---

## 3. Testes de Carga e Concorrência (k6)

Cenários de estresse e concorrência para validação de integridade transacional sob alto volume (*race conditions* na reserva do mesmo assento, rajadas de login e conexões simultâneas de WebSocket).

* **Diretório:** [`tests/load/`](../tests/load/)

### Exemplos de Execução:
```powershell
# Teste de concorrência em cadeira simultânea
k6 run tests/load/concurrency_test.js

# Teste de burst de autenticação
k6 run tests/load/login_burst_test.js
```

> [!WARNING]
> **Atenção:** Os testes de carga devem ser executados exclusivamente em ambientes locais ou de Homologação/Staging. **Nunca execute scripts de estresse contra o ambiente de Produção.**