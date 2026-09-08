# Bloco 4 - Validacao e hardening de entrada

Todas as rotas que recebem entrada externa devem usar `validateRequest` antes do controller.
Os schemas Zod rejeitam campos desconhecidos, normalizam tipos quando seguro e limitam tamanho,
formato e faixa dos valores.

## Limites por endpoint

| Modulo | Entrada | Regras principais |
| --- | --- | --- |
| Auth | login, MFA, SSO, reset e refresh | strings limitadas, e-mail valido, codigos com 6 digitos, tokens ate 512/4096 caracteres |
| Reservas | criacao, check-in, IDs e listagens | IDs inteiros positivos, data `YYYY-MM-DD`, pagina `limit` 1-100 e `offset` ate 100000 |
| Escritorios | mapa | ID inteiro positivo e data opcional `YYYY-MM-DD` |
| Admin usuarios | usuarios, departamentos e importacao | nomes 255, e-mails 255, matriculas 50, lote ate 1000 registros |
| Admin reservas | filtros e cancelamento | datas validas, status enumerado, busca 255, justificativa 1000 |
| Relatorios | filtros e exportacao | datas validas, filtros textuais limitados, pagina/limite controlados |
| Facilities | manutencao e historico | motivo 500, IDs positivos, pagina controlada |
| TI | configuracoes e teste SMTP | whitelist de campos, valores numericos/booleanos, segredos limitados, e-mail valido |
| Auditoria | filtros | pagina 1-100000, limite 10-100, termo 255 |
| SCIM | usuarios, filtros e PATCH | IDs positivos, e-mails validos, filtro 500, no maximo 20 operacoes PATCH |

O parser JSON global aceita no maximo `256kb`. Payloads maiores sao rejeitados antes da logica
de negocio pelo Express/body-parser.