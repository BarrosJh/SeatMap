# 📚 Portal de Documentação Técnica e Corporativa - SeatMap

Bem-vindo ao repositório central de documentação técnica, governança de segurança e procedimentos operacionais do sistema **SeatMap**.

---

## 🧭 Índice Geral de Documentação

### 🔒 1. Segurança, Criptografia e Políticas
* [**Política de Governança de Segredos & Gestão Criptográfica (`SECURITY_POLICIES.md`)**](SECURITY_POLICIES.md): Gestão de credenciais, conformidade BACEN CMN 4.893 / LGPD, matriz de rotação, cifra AES-256-GCM e resposta a incidentes.
* [**Validação e Hardening de Entrada (`backend/VALIDACAO_ENTRADA.md`)**](backend/VALIDACAO_ENTRADA.md): Validação de contratos, limites de payload e regras com esquemas Zod.
* [**Rate Limiting e Proteção contra Abuso (`backend/RATE_LIMITING.md`)**](backend/RATE_LIMITING.md): Janelas de tráfego, limites de requisições, mitigação de força bruta e auditoria.
* [**Política de Sessão e Armazenamento Seguro (`frontend/POLITICA_SESSAO.md`)**](frontend/POLITICA_SESSAO.md): Ciclo de vida de tokens no cliente, cofre `FlutterSecureStorage` e *single-flight refresh*.

### ⚙️ 2. Operações, Continuidade (DR) e SRE
* [**Política de Backup, Restore e Continuidade (`BACKUP_RESTORE.md`)**](BACKUP_RESTORE.md): RPO/RTO, retenção de 30 dias, validação de integridade SHA-256 e plano de Disaster Recovery.
* [**Guia Operacional de Scripts de Automação (`operations/SCRIPTS.md`)**](operations/SCRIPTS.md): Manual dos scripts Bash e PowerShell para rotinas agendadas (Cron e Windows Task Scheduler).
* [**Observabilidade e Resposta a Incidentes (`backend/OBSERVABILIDADE.md`)**](backend/OBSERVABILIDADE.md): Logs estruturados JSON, `X-Correlation-Id`, alertas, sondas de saúde e runbook de triagem.
* [**Deploy e Infraestrutura (`INFRAESTRUTURA.md`)**](INFRAESTRUTURA.md): Configurações para staging/produção, gestão de segredos KMS e isolamento de rede.
* [**Engenharia de Banco de Dados e Performance (`BANCO_PERFORMANCE.md`)**](BANCO_PERFORMANCE.md): Estratégia de indexação PostgreSQL, planos de execução e metas de latência.

### 🚀 3. Governança de Releases e Qualidade
* [**Governança de Releases e Quality Gates (`RELEASE_GOVERNANCE.md`)**](RELEASE_GOVERNANCE.md): Esteira DevSecOps, critérios de aprovação/reprovação de PRs e estratégias de rollback.
* [**Checklist de Release (`RELEASE_CHECKLIST.md`)**](RELEASE_CHECKLIST.md): Roteiro prático para liberação segura de versões em staging e produção.
* [**Estratégia e Execução de Testes (`TESTES.md`)**](TESTES.md): Guia de execução dos testes unitários, integração (Jest), testes Flutter e carga (k6).

### 🌐 4. Contratos e APIs
* [**Especificação OpenAPI 3.0.3 (`openapi.yaml`)**](openapi.yaml): Contrato estruturado de todos os endpoints RESTful da API para integrações e auditoria.

