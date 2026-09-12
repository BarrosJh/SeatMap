# 📱 Guia de Geração e Implantação de QR Codes para Mesas (SeatMap)

Este documento descreve o padrão técnico, os formatos aceitos, os métodos de geração em lote e as recomendações físicas para a impressão e afixação dos **QR Codes de Check-in** nas mesas dos escritórios do **SeatMap**.

---

## 1. Padrão Técnico do QR Code

O leitor integrado ao aplicativo SeatMap utiliza um parser que aceita formatos padronizados para identificar a mesa física no momento do check-in.

### 1.1 Formato Oficial Recomendado (Padrão Corporativo)

```text
SEATMAP:DESK:<escritorioId>:<cadeiraId>
```
ou de forma simplificada:
```text
SEATMAP:DESK:<cadeiraId>
```

#### Exemplos Práticos:
* Mesa do **Escritório ID 1**, com a **Cadeira ID 12**:
  👉 `SEATMAP:DESK:1:12`
* Mesa com **Cadeira ID 45**:
  👉 `SEATMAP:DESK:45`

---

### 1.2 Formatos Alternativos Suportados

O scanner também reconhece e processa automaticamente os seguintes formatos:

| Formato | Exemplo de Payload | Observação |
| :--- | :--- | :--- |
| **JSON Estruturado** | `{"cadeiraId": 12}` ou `{"id": 12}` | Ideal para integrações com sistemas externos |
| **Prefixo Simples** | `MESA_12`, `DESK_12` ou `CADEIRA_12` | Leitura tolerante a prefixos em texto |
| **Numérico Direto** | `12` | Apenas o ID numérico da mesa |

> ⚠️ **Importante:** O identificador numérico contido no QR Code deve corresponder estritamente ao campo **`id`** da tabela `cadeiras` no banco de dados (chave primária).

---

## 2. Como Obter os IDs das Mesas

Para gerar as etiquetas com precisão, consulte os IDs das cadeiras ativas através do banco de dados ou da API:

### 2.1 Consulta via PostgreSQL
```sql
SELECT 
    e.id AS escritorio_id,
    e.nome AS escritorio_nome,
    b.id AS baia_id,
    b.nome AS baia_nome,
    c.id AS cadeira_id,
    c.identificador AS mesa_identificador,
    c.posicao_x,
    c.posicao_y
FROM cadeiras c
JOIN baias b ON c.baia_id = b.id
JOIN escritorios e ON b.escritorio_id = e.id
WHERE c.ativa = true AND e.ativo = true
ORDER BY e.id, b.id, c.id;
```

### 2.2 Consulta via API REST
Endpoint:
```http
GET /api/escritorios/:id/mapa?data=YYYY-MM-DD
Authorization: Bearer <TOKEN>
```
Cada objeto no array `cadeiras` contém `id` (ex: `12`) e `identificador` (ex: `"MESA-12"` ou `"01"`).

---

## 3. Métodos para Gerar os QR Codes

### 3.1 Geração Rápida / Testes Unitários (Online)
Para gerar QR Codes individuais de teste:
1. Acesse um gerador confiável como [QR Code Generator](https://www.qr-code-generator.com/) ou [QRCode Monkey](https://www.qrcode-monkey.com/).
2. Selecione o tipo **Texto Puro (Plain Text)**.
3. Insira o valor: `SEATMAP:DESK:1:12`
4. Exporte em alta resolução (**PNG 1000x1000px** ou **SVG**).

---

### 3.2 Geração em Lote via Script Node.js

Você pode gerar todas as imagens PNG automaticamente executando um script Node.js simples:

```bash
npm install qrcode
```

```javascript
// generate_qrcodes.js
const QRCode = require('qrcode');
const fs = require('fs');
const path = require('path');

const outputDir = path.join(__dirname, 'qrcodes');
if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir);

// Lista de mesas: [ { id: 1, mesa: '01', escritorioId: 1 }, ... ]
const mesas = [
  { id: 1, mesa: '01', escritorioId: 1 },
  { id: 2, mesa: '02', escritorioId: 1 },
  { id: 3, mesa: '03', escritorioId: 1 },
];

async function gerar() {
  for (const item of mesas) {
    const payload = `SEATMAP:DESK:${item.escritorioId}:${item.id}`;
    const filePath = path.join(outputDir, `mesa_${item.mesa}_id_${item.id}.png`);
    
    await QRCode.toFile(filePath, payload, {
      width: 600,
      margin: 2,
      color: {
        dark: '#0F172A', // Cor grafite escuro/azul marinho corporativo
        light: '#FFFFFF'
      }
    });
    console.log(`Gerado: ${filePath} -> ${payload}`);
  }
}

gerar();
```

---

## 4. Especificações Físicas para Impressão e Aplicação

Para garantir que a câmera do celular dos colaboradores faça a leitura instantânea mesmo sob diferentes condições de luz:

```text
┌───────────────────────────────────────┐
│           SEATMAP INTERNAL            │
│                                       │
│          ┌─────────────────┐          │
│          │  █████ █ █████  │          │
│          │  █   █ █ █   █  │          │
│          │  █████ █ █████  │          │
│          │  █ █   █ █ █ █  │          │
│          │  ███ █ █ █████  │          │
│          └─────────────────┘          │
│                                       │
│               MESA 12                 │
│         Baia TI • 2º Andar            │
│                                       │
│   Aponte a câmera no app p/ check-in  │
└───────────────────────────────────────┘
```

### 4.1 Recomendações Técnicas:
1. **Dimensão da Etiqueta:** Mínimo de **4,0 cm x 4,0 cm** (ideal: **5,0 cm x 5,0 cm** a **6,0 cm x 8,0 cm** incluindo texto e logo).
2. **Material:**
   - **Adesivo Vinílico Fosco (Matte):** Evita reflexos de lâmpadas fluorescentes/LED do teto que podem ofuscar a câmera.
   - **Laminação Protetora:** Protege contra desgaste por álcool 70% e produtos de limpeza corporativos.
   - **Display de Acrílico (Opcional):** Suporte inclinado tipo "L" ou "T" de acrílico cristal posicionado sobre a mesa.
3. **Posicionamento na Mesa:**
   - Canto superior direito ou canto superior esquerdo da mesa.
   - Posição livre de mousepads, monitores ou teclados.
4. **Contraste de Cor:** Fundo 100% branco com os módulos do QR Code em preto `#000000` ou azul escuro corporativo `#0F172A`.

---

## 5. Fluxo de Validação de Check-in no Sistema

1. O colaborador acessa a aba **Check-in** no app SeatMap.
2. A câmera do dispositivo lê o QR Code da mesa.
3. O app extrai o `cadeiraId` do payload.
4. O app compara o ID lido com a reserva ativa do colaborador para o dia:
   - **Se o ID bater com a reserva de hoje:** O check-in é confirmado no backend (`POST /api/reservas/:id/checkin`), o status é emitido em tempo real via WebSocket para todos os usuários e o comprovante digital é exibido.
   - **Se o colaborador leu a mesa errada:** O sistema bloqueia e alerta: *"QR Code pertence à Mesa X, mas sua reserva de hoje é para a Mesa Y"*.
   - **Se o colaborador não possui reserva hoje:** O sistema alerta e oferece o botão para ir ao Mapa e realizar a reserva.
