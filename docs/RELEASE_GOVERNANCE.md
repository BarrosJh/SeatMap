# Governança de Releases e Quality Gates (DevSecOps)

## Pipeline Obrigatório de CI/CD

O workflow [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) executa os seguintes gates automatizados em cada Pull Request e push para a branch `main`:

1. **Secret Scanning (Gitleaks):** Inspeção estática de commits para prevenção de vazamento de segredos/chaves;
2. **Backend Quality Gate:** `npm ci`, `npm audit --audit-level=high`, `npm run typecheck`, `npm run build` e suíte de testes unitários/integração Jest;
3. **Frontend Quality Gate:** `flutter pub get`, `flutter analyze`, `flutter test` e build de release web;
4. **Dependency & Supply-Chain Review:** Verificação de vulnerabilidades em dependências via GitHub Dependency Review e Trivy;
5. **SAST & Análise Estática:** Análise contínua de vulnerabilidades de código;
6. **Agregador `quality-gate`:** Job unificador que bloqueia a integração caso qualquer verificação anterior falhe;
7. **Smoke Test de Staging:** Executado mediante promoção controlada (`run_staging_smoke=true`) validando `/api/health/ready` e `/api/health/metrics`.

O ambiente GitHub `staging` deve exigir aprovacao dos responsaveis e fornecer a variavel
`STAGING_HEALTH_URL`. O smoke test verifica `/api/health/ready` e `/api/health/metrics`.
Antes de ativar branch protection, substitua os owners de exemplo em `.github/CODEOWNERS` pelos
usuarios ou times reais do repositorio.

## Criterios aprovados

Uma mudanca pode ser liberada somente quando:

- todos os jobs obrigatorios estiverem verdes;
- nao houver vulnerabilidade alta ou critica nova em dependencias;
- typecheck, build e testes estiverem verdes;
- a revisao de PR tiver aprovacao dos owners de seguranca/dados quando os arquivos forem afetados;
- migrations tiverem sido revisadas e forem compativeis com a estrategia de rollback;
- staging tiver passado pelo smoke test e pela aprovacao do ambiente;
- checklist de release estiver preenchido e anexado ao PR ou ticket.

## Criterios reprovados

Reprovar e bloquear merge/deploy quando houver:

- qualquer falha em backend, frontend, build, teste ou auditoria de dependencias;
- segredo, token, senha ou dado pessoal em codigo, logs ou artefatos;
- migration destrutiva sem plano de backup/restore e aprovacao explicita;
- alteracao de autorizacao, sessao, rate limit ou armazenamento seguro sem revisao de seguranca;
- staging indisponivel, health check falhando ou smoke test incompleto;
- rollback nao definido para mudanca de schema ou deploy.

## Processo de PR

O autor deve descrever risco, impacto, migration, rollback e testes. O revisor deve conferir
especialmente autenticacao, autorizacao, entrada, dados sensiveis, transacoes, logs e limites.
Mudancas em `.github`, banco, middleware, servicos de seguranca ou sessao exigem owners de
seguranca/plataforma conforme `.github/CODEOWNERS`.

## Fluxo de deploy

1. Abrir PR e executar todos os gates automaticamente.
2. Obter aprovacoes obrigatorias.
3. Fazer merge somente com branch protection exigindo `quality-gate`.
4. Gerar artefato/imagem imutavel identificado por commit ou tag.
5. Executar deploy em staging.
6. Promover manualmente o workflow com `run_staging_smoke=true` e aprovar o ambiente `staging`.
7. Executar smoke test funcional e observar logs, metricas, erros 5xx e readiness.
8. Promover a mesma imagem para producao, sem rebuild.
9. Monitorar a janela pos-deploy e registrar resultado.

## Rollback

- Aplicacao: reimplantar a ultima imagem aprovada, identificada por commit/tag.
- Banco: nao fazer rollback SQL automatico de migration destrutiva; usar backup/snapshot e o
  procedimento de [BACKUP_RESTORE.md](BACKUP_RESTORE.md).
- Se a migration for backward-compatible, voltar a imagem anterior mantendo o schema.
- Se houver incompatibilidade, pausar trafego, restaurar em ambiente controlado e executar cutover aprovado.
- Apos rollback, validar health, login, reserva, auditoria, WebSocket e metricas.

## Protecao do ambiente

Branch protection deve exigir `quality-gate`, revisao dos CODEOWNERS e branch atualizada antes
do merge. Deploy de producao deve exigir aprovacao manual separada de staging e permissao minima
para secrets/ambientes.
