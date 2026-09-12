# Política de Governança de Segredos & Gestão Criptográfica

**Versão:** 1.0.0  
**Classificação:** Confidencial / Corporativo  
**Conformidade:** Resolução CMN nº 4.893 (BACEN), LGPD (Lei 13.709/2018), Princípios NIST SP 800-63B e Arquitetura Zero Trust.

---

## 1. Objetivo e Escopo

Este documento estabelece as diretrizes obrigatórias de segurança, ciclo de vida, rotação periódica e resposta a incidentes para todos os segredos criptográficos, credenciais de bancos de dados, tokens de APIs e certificados digitais utilizados no ecossistema **SeatMap**.

Aplica-se a todos os ambientes (**Desenvolvimento, Staging e Produção**), operadores de infraestrutura, desenvolvedores e pipelines de CI/CD.

---

## 2. Princípios de Segurança

1. **Segredos Nunca Versionados (Zero Hardcoded Secrets)**:
   - É terminantemente proibido comitar credenciais, senhas, chaves privadas ou tokens em repositórios de código-fonte.
   - Todo commit é inspecionado automaticamente pelo `gitleaks` no CI.
2. **Menor Privilégio e Segregação de Funções**:
   - Acesso a segredos de produção é restrito à equipe de Administração de TI e Infraestrutura mediante MFA e aprovação auditada.
3. **Cifragem em Repouso e em Trânsito (End-to-End Encryption)**:
   - Dados sensíveis em repouso (ex.: segredos TOTP e backup codes) utilizam cifragem simétrica **AES-256-GCM** com vetor de inicialização (IV) e tag de autenticação únicos.
   - Comunicações externas e internas utilizam **TLS 1.3** obrigatório.

---

## 3. Matriz de Rotação Periódica de Segredos

| Identificador do Segredo | Descrição e Finalidade | Criticidade | Frequência de Rotação | Procedimento de Rotação |
| :--- | :--- | :---: | :---: | :--- |
| **`JWT_SECRET`** | Chave mestra de assinatura dos Access Tokens (15m) e validação de sessão. | **P0 - Crítica** | A cada **60 dias** ou incidente | Rotação sem downtime via transição de chaves com revogação progressiva. |
| **`JWT_ADMIN_SECRET`** | Chave de assinatura para Step-Up MFA administrativo (`x-admin-token`). | **P0 - Crítica** | A cada **60 dias** ou incidente | Atualização no cofre; exige nova validação MFA no painel. |
| **`ENCRYPTION_KEY`** | Chave AES-256-GCM de cifragem de segredos TOTP no PostgreSQL. | **P0 - Crítica** | A cada **90 dias** ou incidente | Re-encriptação em lote via script `npm run db:reencrypt`. |
| **`DB_PASSWORD`** | Senha do usuário de aplicação no PostgreSQL. | **P1 - Alta** | A cada **90 dias** | Alteração no banco via RDS/Cloud SQL e injeção da nova variável. |
| **`INTERNAL_HEALTH_TOKEN`** | Token de sondas de liveness/readiness e métricas Prometheus. | **P1 - Alta** | A cada **90 dias** | Atualização simultânea no Kubernetes/Scraper e na API. |
| **`SCIM_BEARER_TOKEN`** | Token de integração com IdP para provisionamento RFC 7644. | **P1 - Alta** | A cada **90 dias** | Rotação coordenada no Microsoft Entra ID / Okta. |
| **`SMTP_PASS`** | Senha/Token de serviço SMTP para envio de códigos MFA e alertas. | **P2 - Média** | A cada **180 dias** | Geração de novo App Password no servidor SMTP. |

---

## 4. Integração com Cofres de Segredos (Key Vaults)

Em ambientes de Homologação (Staging) e Produção, todas as variáveis sensíveis devem ser injetadas em tempo de execução a partir de provedores gerenciados de Key Management Service (KMS):

```
+------------------------+      TLS 1.3      +------------------------+
|  Azure Key Vault /     | ----------------> |  SeatMap Container     |
|  AWS Secrets Manager / |  (KMS Injected)   |  (Backend Node.js API) |
|  HashiCorp Vault       |                   |                        |
+------------------------+                   +------------------------+
```

### Configuração por Provedor:
- **Azure Key Vault**: Mapeamento via Managed Identity (`AZURE_CLIENT_ID`) e injeção automática no App Service / Azure Container Apps.
- **AWS Secrets Manager**: Injeção via ECS Task Definition ou AWS Secrets CSI Driver no EKS.
- **Kubernetes (On-Premises)**: Utilização do **External Secrets Operator (ESO)** sincronizado com HashiCorp Vault.

---

## 5. Procedimento Operacional Padrão (POP) - Resposta a Incidentes de Comprometimento

Em caso de suspeita fundamentada ou confirmação de vazamento de segredos:

### Passo 1: Ativação do Kill-Switch de Sessões
1. Acessar o banco de produção e executar a revogação global em cascata:
   ```sql
   -- Incrementa a versão de todos os usuários, invalidando todos os Access Tokens ativos
   UPDATE usuarios SET token_version = COALESCE(token_version, 1) + 1;
   
   -- Revoga imediatamente todos os Refresh Tokens
   UPDATE auth_refresh_tokens SET revogado = true;
   ```

### Passo 2: Rotação Imediata da Chave Comprometida no Key Vault
1. Gerar novo segredo de alta entropia (mínimo 32 bytes / 256 bits aleatórios):
   ```bash
   node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
   ```
2. Atualizar o valor no Cofre de Segredos (Key Vault).
3. Executar o redeploy ou reload gracioso dos containers da API (`kubectl rollout restart` ou restart no Render/AWS).

### Passo 3: Trilha e Notificação
1. Consultar os logs de auditoria na tabela `auditoria_logs` para verificar possíveis acessos anômalos no intervalo do incidente:
   ```sql
   SELECT * FROM auditoria_logs WHERE criado_em >= NOW() - INTERVAL '24 HOURS' ORDER BY id DESC;
   ```
2. Registrar o incidente no Relatório de Não-Conformidade de Segurança conforme exigido pela resolução BACEN CMN 4.893.

---

## 6. Checklist de Conformidade BACEN CMN 4.893 & Zero Trust

- [x] **Gestão de Sessão Restrita**: Tokens de acesso com TTL máximo de 15 minutos e timeout absoluto de 60 minutos.
- [x] **Prevenção de Sessões Simultâneas**: Invalidação de sessões anteriores no momento do login.
- [x] **Autenticação Multifator Privilegiada**: MFA obrigatório para perfis `ADMIN_RH`, `ADMIN_TI` e `GESTAO`.
- [x] **Proteção de Headers Web**: CSP estrito, Permissions-Policy, Anti-cache e isolamento Same-Origin.
- [x] **Imutabilidade e Trilha de Auditoria**: Registro estruturado de IP, User-Agent, Correlation-ID e tipo de evento em todas as operações sensíveis.

