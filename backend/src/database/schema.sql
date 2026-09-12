-- Schema DDL para SeatMap Internal
-- Banco de Dados: PostgreSQL 16
-- Fuso Horário padrão: America/Sao_Paulo

-- Tabela: escritorios
CREATE TABLE IF NOT EXISTS escritorios (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    cidade VARCHAR(255) NOT NULL,
    ativo BOOLEAN DEFAULT true
);

-- Tabela: departamentos
CREATE TABLE IF NOT EXISTS departamentos (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(255) NOT NULL UNIQUE
);

-- Tabela: usuarios
CREATE TABLE IF NOT EXISTS usuarios (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    matricula VARCHAR(100) NOT NULL UNIQUE,
    senha_hash VARCHAR(255) NOT NULL,
    departamento_id INT REFERENCES departamentos(id) ON DELETE SET NULL,
    perfil VARCHAR(50) NOT NULL CHECK (perfil IN ('COLABORADOR', 'GESTAO', 'ADMIN_RH', 'ADMIN_TI')),
    permissao_rh BOOLEAN DEFAULT false,
    permissao_ti BOOLEAN DEFAULT false,
    ativo BOOLEAN DEFAULT true
);

ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS permissao_ti BOOLEAN DEFAULT false;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS criado_em TIMESTAMP DEFAULT NOW();
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS atualizado_em TIMESTAMP DEFAULT NOW();
ALTER TABLE usuarios DROP CONSTRAINT IF EXISTS usuarios_perfil_check;
ALTER TABLE usuarios ADD CONSTRAINT usuarios_perfil_check CHECK (perfil IN ('COLABORADOR', 'GESTAO', 'ADMIN_RH', 'ADMIN_TI'));

-- Tabela: baias
CREATE TABLE IF NOT EXISTS baias (
    id SERIAL PRIMARY KEY,
    escritorio_id INT NOT NULL REFERENCES escritorios(id) ON DELETE CASCADE,
    nome VARCHAR(255) NOT NULL
);

-- Tabela: cadeiras
CREATE TABLE IF NOT EXISTS cadeiras (
    id SERIAL PRIMARY KEY,
    baia_id INT NOT NULL REFERENCES baias(id) ON DELETE CASCADE,
    identificador VARCHAR(50) NOT NULL,
    posicao_x INT NOT NULL,
    posicao_y INT NOT NULL,
    ativa BOOLEAN DEFAULT true
);

-- Tabela: reservas
CREATE TABLE IF NOT EXISTS reservas (
    id SERIAL PRIMARY KEY,
    cadeira_id INT NOT NULL REFERENCES cadeiras(id) ON DELETE CASCADE,
    usuario_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    data_reserva DATE NOT NULL,
    checkin_realizado BOOLEAN DEFAULT false,
    checkin_em TIMESTAMP,
    checkout_em TIMESTAMP,
    status VARCHAR(50) DEFAULT 'ATIVA' CHECK (status IN ('ATIVA', 'CANCELADA', 'EXPIRADA_NOSHOW', 'CONCLUIDA')),
    codigo_comprovante VARCHAR(64) UNIQUE,
    criado_em TIMESTAMP DEFAULT NOW()
);

ALTER TABLE reservas ADD COLUMN IF NOT EXISTS checkout_em TIMESTAMP;
ALTER TABLE reservas DROP CONSTRAINT IF EXISTS reservas_status_check;
ALTER TABLE reservas ADD CONSTRAINT reservas_status_check CHECK (status IN ('ATIVA', 'CANCELADA', 'EXPIRADA_NOSHOW', 'CONCLUIDA'));

-- Índices adicionais e parciais para alta concorrência e integridade de reservas ativas
CREATE UNIQUE INDEX IF NOT EXISTS unq_cadeira_data_ativa ON reservas (cadeira_id, data_reserva) WHERE status = 'ATIVA';
CREATE UNIQUE INDEX IF NOT EXISTS unq_usuario_data_ativa ON reservas (usuario_id, data_reserva) WHERE status = 'ATIVA';
CREATE INDEX IF NOT EXISTS idx_reservas_data_status ON reservas(data_reserva, status);
CREATE INDEX IF NOT EXISTS idx_reservas_usuario_data ON reservas(usuario_id, data_reserva);
CREATE INDEX IF NOT EXISTS idx_reservas_relatorio ON reservas(data_reserva, status, usuario_id, checkin_realizado);
-- Índices alinhados às listagens paginadas e à ordenação mais frequente.
CREATE INDEX IF NOT EXISTS idx_reservas_usuario_data_id ON reservas(usuario_id, data_reserva DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_reservas_data_criado_id ON reservas(data_reserva DESC, criado_em DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_usuarios_dept_ativo ON usuarios(departamento_id, ativo);
CREATE INDEX IF NOT EXISTS idx_cadeiras_baia ON cadeiras(baia_id);
CREATE INDEX IF NOT EXISTS idx_baias_escritorio ON baias(escritorio_id);


-- Tabela: configuracoes_sistema
CREATE TABLE IF NOT EXISTS configuracoes_sistema (
    chave VARCHAR(100) PRIMARY KEY,
    valor TEXT NOT NULL,
    descricao TEXT
);

ALTER TABLE configuracoes_sistema ALTER COLUMN valor TYPE TEXT;
ALTER TABLE configuracoes_sistema ALTER COLUMN descricao TYPE TEXT;

-- Tabela: auth_mfa_codes
CREATE TABLE IF NOT EXISTS auth_mfa_codes (
    id SERIAL PRIMARY KEY,
    usuario_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    codigo VARCHAR(6) NOT NULL,
    expira_em TIMESTAMP NOT NULL,
    utilizado BOOLEAN DEFAULT false,
    criado_em TIMESTAMP DEFAULT NOW()
);

-- Tabela: auth_password_resets
CREATE TABLE IF NOT EXISTS auth_password_resets (
    id SERIAL PRIMARY KEY,
    usuario_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    codigo VARCHAR(6) NOT NULL,
    expira_em TIMESTAMP NOT NULL,
    utilizado BOOLEAN DEFAULT false,
    tentativas INT DEFAULT 0,
    criado_em TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_password_resets_usuario ON auth_password_resets(usuario_id, utilizado);
CREATE INDEX IF NOT EXISTS idx_mfa_codes_usuario_utilizado_expira ON auth_mfa_codes(usuario_id, utilizado, expira_em DESC);

-- Colunas de Segurança, TOTP e SSO na tabela usuarios
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS tentativas_login_falhas INT DEFAULT 0;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS bloqueado_ate TIMESTAMP;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS totp_secret TEXT;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS totp_ativo BOOLEAN DEFAULT false;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS totp_backup_codes TEXT;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS ultimo_login TIMESTAMP;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS sso_provider VARCHAR(50);
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS sso_id VARCHAR(255);
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS exigir_mfa BOOLEAN DEFAULT false;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS token_version INT DEFAULT 1 NOT NULL;
CREATE INDEX IF NOT EXISTS idx_usuarios_sso ON usuarios(sso_provider, sso_id);

-- Inserir chaves padrão para Bloqueio de Sessão por Inatividade
INSERT INTO configuracoes_sistema (chave, valor, descricao)
VALUES 
    ('AUTO_LOCK_ATIVO', 'true', 'Bloqueio automático de sessão por inatividade (Sim/Não)'),
    ('AUTO_LOCK_MINUTOS', '15', 'Tempo limite de inatividade em minutos antes do auto-lock')
ON CONFLICT (chave) DO NOTHING;

-- Tabela: auditoria_acessos
CREATE TABLE IF NOT EXISTS auditoria_acessos (
    id SERIAL PRIMARY KEY,
    usuario_id INT REFERENCES usuarios(id) ON DELETE SET NULL,
    login_informado VARCHAR(255),
    tipo_evento VARCHAR(50) NOT NULL,
    sucesso BOOLEAN NOT NULL,
    ip VARCHAR(100),
    user_agent TEXT,
    detalhes JSONB,
    criado_em TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_auditoria_usuario ON auditoria_acessos(usuario_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_tipo ON auditoria_acessos(tipo_evento);
CREATE INDEX IF NOT EXISTS idx_auditoria_criado_em ON auditoria_acessos(criado_em DESC);

-- Tabela: auth_refresh_tokens (Gestão de sessão com rotação)
CREATE TABLE IF NOT EXISTS auth_refresh_tokens (
    id SERIAL PRIMARY KEY,
    usuario_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    family_id VARCHAR(64) NOT NULL,
    revogado BOOLEAN DEFAULT false,
    expira_em TIMESTAMP NOT NULL,
    ip VARCHAR(100),
    user_agent TEXT,
    criado_em TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_family ON auth_refresh_tokens(family_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_usuario ON auth_refresh_tokens(usuario_id, revogado);

-- Colunas de Gestão de Manutenção de Assentos na tabela cadeiras
ALTER TABLE cadeiras ADD COLUMN IF NOT EXISTS status_operacional VARCHAR(50) DEFAULT 'DISPONIVEL';
ALTER TABLE cadeiras DROP CONSTRAINT IF EXISTS cadeiras_status_operacional_check;
ALTER TABLE cadeiras ADD CONSTRAINT cadeiras_status_operacional_check CHECK (status_operacional IN ('DISPONIVEL', 'EM_MANUTENCAO'));
ALTER TABLE cadeiras ADD COLUMN IF NOT EXISTS motivo_manutencao TEXT;
ALTER TABLE cadeiras ADD COLUMN IF NOT EXISTS previsao_retorno TIMESTAMP;
ALTER TABLE cadeiras ADD COLUMN IF NOT EXISTS manutencao_por_usuario_id INT REFERENCES usuarios(id) ON DELETE SET NULL;

-- Tabela: historico_reservas (Trilha de auditoria e ciclo de vida de reservas)
CREATE TABLE IF NOT EXISTS historico_reservas (
    id SERIAL PRIMARY KEY,
    reserva_id INT REFERENCES reservas(id) ON DELETE SET NULL,
    cadeira_id INT NOT NULL REFERENCES cadeiras(id) ON DELETE CASCADE,
    usuario_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    data_reserva DATE NOT NULL,
    tipo_evento VARCHAR(50) NOT NULL CHECK (tipo_evento IN ('CRIADA', 'TROCADA', 'CHECKIN', 'CANCELADA_USUARIO', 'CANCELADA_GESTAO', 'CANCELADA_MANUTENCAO', 'EXPIRADA_NOSHOW', 'MESA_LIBERADA')),
    executado_por_usuario_id INT REFERENCES usuarios(id) ON DELETE SET NULL,
    motivo TEXT,
    detalhes JSONB,
    criado_em TIMESTAMP DEFAULT NOW()
);

ALTER TABLE historico_reservas DROP CONSTRAINT IF EXISTS historico_reservas_tipo_evento_check;
ALTER TABLE historico_reservas ADD CONSTRAINT historico_reservas_tipo_evento_check CHECK (tipo_evento IN ('CRIADA', 'TROCADA', 'CHECKIN', 'CANCELADA_USUARIO', 'CANCELADA_GESTAO', 'CANCELADA_MANUTENCAO', 'EXPIRADA_NOSHOW', 'MESA_LIBERADA'));

CREATE INDEX IF NOT EXISTS idx_historico_cadeira_data ON historico_reservas(cadeira_id, data_reserva);
CREATE INDEX IF NOT EXISTS idx_historico_usuario ON historico_reservas(usuario_id);
CREATE INDEX IF NOT EXISTS idx_historico_reserva ON historico_reservas(reserva_id);
CREATE INDEX IF NOT EXISTS idx_historico_criado_em ON historico_reservas(criado_em DESC);
CREATE INDEX IF NOT EXISTS idx_historico_tipo ON historico_reservas(tipo_evento);
CREATE INDEX IF NOT EXISTS idx_historico_cadeira_criado_id ON historico_reservas(cadeira_id, criado_em DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_historico_usuario_criado_id ON historico_reservas(usuario_id, criado_em DESC, id DESC);

-- ======================================================================================
-- GARANTIA DE NÃO-REPÚDIO E IMUTABILIDADE DE LOGS (PADRÃO BANCÁRIO BACEN / CMN 4.893 WORM)
-- ======================================================================================
CREATE OR REPLACE FUNCTION trg_prevent_audit_tampering()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Operação não permitida: Registros de auditoria são imutáveis (Regulatório BACEN / WORM).';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auditoria_acessos_immutable ON auditoria_acessos;
CREATE TRIGGER trg_auditoria_acessos_immutable
BEFORE UPDATE OR DELETE ON auditoria_acessos
FOR EACH ROW EXECUTE FUNCTION trg_prevent_audit_tampering();

DROP TRIGGER IF EXISTS trg_historico_reservas_immutable ON historico_reservas;
CREATE TRIGGER trg_historico_reservas_immutable
BEFORE UPDATE OR DELETE ON historico_reservas
FOR EACH ROW EXECUTE FUNCTION trg_prevent_audit_tampering();

-- ======================================================================================
-- AUTENTICAÇÃO BIOMÉTRICA NATIVA & PASSKEYS (WEBAUTHN / FIDO2 / W3C STANDARD)
-- ======================================================================================
CREATE TABLE IF NOT EXISTS usuarios_biometria_passkeys (
    id SERIAL PRIMARY KEY,
    usuario_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    credential_id TEXT NOT NULL UNIQUE,
    public_key TEXT NOT NULL,
    counter BIGINT NOT NULL DEFAULT 0,
    transports TEXT[] DEFAULT '{}',
    nome_dispositivo VARCHAR(100) DEFAULT 'Dispositivo Móvel',
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ultimo_uso TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_biometria_usuario_id ON usuarios_biometria_passkeys(usuario_id);
CREATE INDEX IF NOT EXISTS idx_biometria_credential_id ON usuarios_biometria_passkeys(credential_id);

-- Tabela: webauthn_challenges (Persistência multi-instância de challenges WebAuthn)
CREATE TABLE IF NOT EXISTS webauthn_challenges (
    key VARCHAR(255) PRIMARY KEY,
    challenge TEXT NOT NULL,
    user_id INT REFERENCES usuarios(id) ON DELETE CASCADE,
    expires_at BIGINT NOT NULL,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_webauthn_challenges_exp ON webauthn_challenges(expires_at);
