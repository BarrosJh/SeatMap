# Testes

## Backend

- `backend/tests/unit/`: testes unitarios Jest.
- `backend/tests/integration/`: scripts de integracao que dependem de API ou banco configurados.

## Frontend

- `frontend/test/`: testes Flutter, mantidos no diretorio padrao do ecossistema Flutter.

## Carga

- `tests/load/`: testes de concorrencia, login burst, WebSocket, pool e cenarios mistos.

Os testes de carga podem exigir Docker, PostgreSQL, API em execucao e usuarios de teste. Nao execute
scripts de carga contra producao.