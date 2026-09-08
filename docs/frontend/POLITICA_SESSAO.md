# Bloco 9 - Politica de sessao no cliente

## Armazenamento

- Access token e refresh token ficam exclusivamente no `FlutterSecureStorage`.
- Dados basicos do usuario ficam no mesmo cofre para restaurar a sessao visualmente.
- O token de step-up administrativo (`x-admin-token`) fica apenas em memoria.
- O token temporario de MFA fica apenas em memoria.
- `SharedPreferences` nao recebe novas credenciais e nao e usado como fallback quando o cofre falha.
- Uma migracao unica remove tokens legados de `SharedPreferences`; se o cofre nao estiver disponivel,
  a migracao falha sem copiar a credencial para armazenamento inseguro.

## Validacao e renovacao

- Na inicializacao, o JWT e decodificado localmente apenas para verificar a validade do campo `exp`.
- A assinatura continua sendo validada pelo backend; a verificacao local so evita abrir telas com token expirado.
- `isAuthenticated` considera a expiracao do access token.
- Respostas HTTP `401` acionam um refresh single-flight, evitando varias rotacoes simultaneas.
- O refresh token rotacionado substitui o anterior no cofre seguro.
- Falha ou excecao no refresh limpa o cofre e encerra a sessao.
- O cliente nunca tenta renovar endpoints de login ou do proprio refresh.

## Logout

O logout captura tokens somente em memoria para tentar revogar o refresh token no servidor, limpa
access token, refresh token, usuario, step-up, MFA temporario e estado de bloqueio, encerra o
WebSocket, remove credenciais do armazenamento seguro e aguarda a chamada de logout do backend.
Mesmo quando a rede esta indisponivel, a limpeza local acontece antes da tentativa de revogacao remota.

## Telas sensiveis

Telas administrativas devem exigir `isAuthenticated` e, quando a API exigir step-up, consultar
`isAdminStepUpAuthenticated`. O perfil do usuario sozinho nao representa MFA validado.

## Limites

O cliente nao e uma fronteira de confianca: expiracao, assinatura, revogacao, permissoes e MFA
continuam sendo decididos pelo backend. A validacao local existe para reduzir exposicao visual e
melhorar a experiencia quando a sessao ja expirou.