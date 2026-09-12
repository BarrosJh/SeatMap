# Modelagem de Ameaças STRIDE & LINDDUN — SeatMap Enterprise

> **Aplicação:** SeatMap Corporativo  
> **Versão:** 1.0.0  
> **Data:** 12/09/2026  
> **Referência Técnica:** OWASP Top 10 (A04: Insecure Design) & Boas Práticas NIST / Zero Trust.

---

## 1. Visão Geral da Arquitetura e Fronteiras de Confiança (Trust Boundaries)

```
[ Usuário / Colaborador ] ----( HTTPS / WSS )----> [ Reverse Proxy / WAF / Helmet ]
                                                          |
                                                    ( Express API )
                                                          |
                      +-------------------+---------------+-------------------+
                      |                   |                                   |
             [ PostgreSQL 16 ]     [ Provedor SSO / IdP ]           [ Key Vault / KMS ]
             (AES-256 Repouso)    (Microsoft Entra ID)             (Segredos & Chaves)
```

### Fronteiras de Confiança:
1. **TB-01: Internet / Rede Externa vs. Borda da Aplicação (Reverse Proxy / WAF):** Tráfego não autenticado, sujeito a ataques de força bruta, DoS e injeções web.
2. **TB-02: Borda vs. Camada de Aplicação (API Node.js):** Validação de identidade, tokens JWT, sessões e permissões RBAC.
3. **TB-03: Camada de Aplicação vs. Banco de Dados PostgreSQL:** Tráfego interno de consultas parametrizadas e dados criptografados.
4. **TB-04: Camada de Aplicação vs. Provedores Externos (SSO / SMTP / Key Vault):** Comunicação TLS 1.3 com validação de JWKS e certificados.

---

## 2. Matriz de Ameaças STRIDE e Contramedidas Implementadas

### S — Spoofing (Falsificação de Identidade)
* **Ameaça:** Atacante tenta forjar credenciais, manipular tokens JWT ou se passar por outro colaborador.
* **Contramedidas Implementadas:**
  * Autenticação Multifator (MFA) via TOTP (RFC 6238) e WebAuthn / Passkeys de hardware;
  * Step-up MFA (`x-admin-token`) para qualquer acesso às configurações administrativas e de RH;
  * Validação dinâmica de versão de sessão (`token_version`) no banco de dados a cada requisição HTTP;
  * Assinatura de tokens JWT com suporte a chaves assimétricas RS256/ES256 e verificação de integridade estrita;
  * Single Sign-On (SSO) com validação de assinatura criptográfica via JWKS pública corporativa.

### T — Tampering (Adulteração de Dados)
* **Ameaça:** Manipulação de parâmetros na URL/Body (ex.: reservar assento de outro usuário ou burlar validações).
* **Contramedidas Implementadas:**
  * Validação estrutural e tipagem estrita de 100% dos payloads via schemas **Zod** (`validateRequest`);
  * Consultas SQL 100% parametrizadas no PostgreSQL (prevenção absoluta de SQL Injection);
  * Verificação de integridade de Refresh Tokens usando Hashing criptográfico SHA-256;
  * Content Security Policy (CSP) e Subresource Integrity (SRI) contra adulteração de scripts web no frontend.

### R — Repudiation (Não-Repúdio)
* **Ameaça:** Usuário executa ações críticas (ex.: cancelamento em lote, alteração de privilégios) e nega a autoria.
* **Contramedidas Implementadas:**
  * Trilha de auditoria centralizada e imutável ([`src/services/auditService.ts`](file:///c:/Assentos/backend/src/services/auditService.ts)) registrando: `timestamp` (UTC), `usuario_id`, `tipo_evento`, `sucesso`, `ip`, `user_agent` e `detalhes` JSON;
  * Rastreabilidade fim-a-fim via injeção de `X-Correlation-ID` em todas as requisições HTTP;
  * Registro de eventos sensíveis: `SESSAO_SIMULTANEA_REVOGADA`, `LOGIN_CONTA_BLOQUEADA`, `SENHA_RESETADA`, `CONFIGURACAO_ALTERADA`.

### I — Information Disclosure (Divulgação Não Autorizada de Informações)
* **Ameaça:** Vazamento de dados pessoais (LGPD), senhas, chaves criptográficas ou stack traces em respostas de erro.
* **Contramedidas Implementadas:**
  * Cifragem simétrica de campos sensíveis (segredos TOTP e backup codes) com **AES-256-GCM**;
  * Hashing de senhas com **Bcrypt Fator de Custo 12** (`saltRounds = 12`);
  * Redação profunda de logs (`redactSensitiveData` e `maskSensitiveData`) ocultando senhas, tokens e CPFs;
  * Middleware [`errorHandler`](file:///c:/Assentos/backend/src/middleware/errorHandler.ts) suprime stack traces em ambiente de produção/staging, retornando mensagens genéricas (OWASP A10:2025);
  * Remoção dos cabeçalhos informativos `Server` e `X-Powered-By`.

### D — Denial of Service (Negação de Serviço)
* **Ameaça:** Esgotamento de recursos por requisições massivas, consultas pesadas ou ataques de força bruta.
* **Contramedidas Implementadas:**
  * 6 camadas de Rate Limiting via `express-rate-limit`: global (900 req/min), autenticação (50 req/min por IP e 5 falhas/15m por conta), exportações e operações em lote;
  * Escape de wildcards SQL (`escapeSqlWildcards`) para evitar DoS por Full Table Scan em buscas textuais;
  * Paginação obrigatória em consultas de auditoria e listagens;
  * Graceful Shutdown com drenagem controlada de conexões e pool PostgreSQL.

### E — Elevation of Privilege (Elevação de Privilégios)
* **Ameaça:** Colaborador comum tenta executar operações administrativas de RH ou TI (BOLA / Broken Object Level Auth).
* **Contramedidas Implementadas:**
  * RBAC granular por permissão (`requirePermission('config:write')`, `requirePermission('infra:write')`);
  * Segregação estrita de funções entre Gestão, Recursos Humanos (`ADMIN_RH`) e Infraestrutura (`ADMIN_TI`);
  * Proibição de auto-atribuição de privilégios superiores na criação e edição de usuários.

---

## 3. Diretrizes de Privacidade LINDDUN (Conformidade LGPD)

1. **Linkability:** Usuários não podem correlacionar reservas de terceiros sem permissão expressa de gestão.
2. **Identifiability:** E-mails e dados de contato são mascarados em desafios de MFA (`j***a@empresa.com`).
3. **Non-repudiation balance:** Logs contêm apenas identificadores mínimos necessários para auditoria legal, sem retenção de senhas em texto claro.
4. **Detectability:** Políticas anti-cache (`no-store, no-cache, must-revalidate`) impedem que dados pessoais fiquem retidos em proxies intermediários ou cache de navegadores.
5. **Information Disclosure:** Segregação lógica por departamento no banco de dados.
6. **Unawareness:** Usuários são informados de suas sessões ativas e notificações de logout forçado por concorrência.
7. **Non-compliance:** Controles alinhados aos requisitos do BACEN (CMN 4.893) e LGPD (Art. 46).

