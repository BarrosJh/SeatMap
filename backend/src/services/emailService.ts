import nodemailer, { Transporter } from 'nodemailer';

export interface ComprovanteEmailData {
  escritorioNome: string;
  escritorioCidade: string;
  baiaNome?: string;
  cadeiraIdentificador: string;
  dataReserva: string;
  codigoComprovante: string;
  tipo?: string;
  emitidoEm?: string;
}

export class EmailService {
  private static transporter: Transporter | null = null;

  private static getTransporter(): Transporter {
    if (!this.transporter) {
      const host = process.env.SMTP_HOST;
      const port = parseInt(process.env.SMTP_PORT || '587', 10);
      const user = process.env.SMTP_USER;
      const pass = process.env.SMTP_PASS;
      const secure = process.env.SMTP_SECURE === 'true' || port === 465;

      if (host && user && pass) {
        this.transporter = nodemailer.createTransport({
          host,
          port,
          secure,
          auth: { user, pass },
          tls: { rejectUnauthorized: false }
        });
      } else {
        // Fallback para desenvolvimento / simulação com JSON transport e logs formatados
        this.transporter = nodemailer.createTransport({
          jsonTransport: true
        });
      }
    }
    return this.transporter;
  }

  private static getFromAddress(): string {
    return process.env.EMAIL_FROM || '"SeatMap Corporativo" <nao-responda@seatmap.local>';
  }

  /**
   * 1. Envio de Código MFA para Gestão / RH
   */
  public static async enviarCodigoMfa(
    para: string,
    nome: string,
    codigo: string,
    expiraMinutos: number = 10
  ): Promise<boolean> {
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F8FAFC; margin: 0; padding: 20px; }
          .container { max-width: 540px; margin: 0 auto; background: #FFFFFF; border-radius: 12px; border: 1px solid #E2E8F0; overflow: hidden; }
          .header { background: #0F172A; padding: 24px; text-align: center; }
          .header h1 { color: #FFFFFF; font-size: 20px; margin: 0; letter-spacing: 0.5px; }
          .content { padding: 30px 24px; text-align: center; }
          .badge { display: inline-block; background: #EDE9FE; color: #6D28D9; font-size: 11px; font-weight: bold; padding: 4px 10px; border-radius: 20px; margin-bottom: 16px; text-transform: uppercase; }
          .code-box { background: #F1F5F9; border: 2px dashed #94A3B8; border-radius: 10px; padding: 18px; margin: 24px 0; font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #0F172A; }
          .info { color: #64748B; font-size: 13px; line-height: 1.5; margin-bottom: 20px; }
          .footer { background: #F8FAFC; padding: 16px; text-align: center; border-top: 1px solid #E2E8F0; font-size: 11px; color: #94A3B8; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>SeatMap Internal</h1>
          </div>
          <div class="content">
            <span class="badge">Autenticação em Duas Etapas (MFA)</span>
            <h2 style="margin: 0 0 10px 0; color: #1E293B; font-size: 18px;">Olá, ${nome}!</h2>
            <p style="color: #475569; font-size: 14px; margin: 0;">Você solicitou acesso ao Painel de Políticas e Gestão de Assentos. Utilize o código de verificação abaixo:</p>
            <div class="code-box">${codigo}</div>
            <p class="info">
              Este código é confidencial e expira em <strong>${expiraMinutos} minutos</strong>.<br>
              Se você não solicitou este código, por favor ignore este e-mail.
            </p>
          </div>
          <div class="footer">
            © ${new Date().getFullYear()} SeatMap Corporate. Mensagem automática, não responda.
          </div>
        </div>
      </body>
      </html>
    `;

    return this.despacharEmail({
      to: para,
      subject: `[SeatMap] Código de Verificação MFA: ${codigo}`,
      html,
      tipoLog: 'MFA_RH',
      codigoDebug: codigo
    });
  }

  /**
   * 2. Envio de Código de Recuperação de Senha (Esqueci Minha Senha)
   */
  public static async enviarCodigoRecuperacaoSenha(
    para: string,
    nome: string,
    codigo: string,
    expiraMinutos: number = 15
  ): Promise<boolean> {
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F8FAFC; margin: 0; padding: 20px; }
          .container { max-width: 540px; margin: 0 auto; background: #FFFFFF; border-radius: 12px; border: 1px solid #E2E8F0; overflow: hidden; }
          .header { background: #0F172A; padding: 24px; text-align: center; }
          .header h1 { color: #FFFFFF; font-size: 20px; margin: 0; letter-spacing: 0.5px; }
          .content { padding: 30px 24px; text-align: center; }
          .badge { display: inline-block; background: #FEF3C7; color: #B45309; font-size: 11px; font-weight: bold; padding: 4px 10px; border-radius: 20px; margin-bottom: 16px; text-transform: uppercase; }
          .code-box { background: #FFFBEB; border: 2px dashed #F59E0B; border-radius: 10px; padding: 18px; margin: 24px 0; font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #B45309; }
          .info { color: #64748B; font-size: 13px; line-height: 1.5; margin-bottom: 20px; }
          .footer { background: #F8FAFC; padding: 16px; text-align: center; border-top: 1px solid #E2E8F0; font-size: 11px; color: #94A3B8; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>SeatMap Internal</h1>
          </div>
          <div class="content">
            <span class="badge">Recuperação de Senha</span>
            <h2 style="margin: 0 0 10px 0; color: #1E293B; font-size: 18px;">Olá, ${nome}!</h2>
            <p style="color: #475569; font-size: 14px; margin: 0;">Recebemos uma solicitação para redefinir a sua senha de acesso. Utilize o código abaixo no aplicativo:</p>
            <div class="code-box">${codigo}</div>
            <p class="info">
              Este código de redefinição é válido por <strong>${expiraMinutos} minutos</strong>.<br>
              Se você não realizou esta solicitação, sua senha atual permanece segura.
            </p>
          </div>
          <div class="footer">
            © ${new Date().getFullYear()} SeatMap Corporate. Mensagem automática, não responda.
          </div>
        </div>
      </body>
      </html>
    `;

    return this.despacharEmail({
      to: para,
      subject: `[SeatMap] Código para Redefinição de Senha: ${codigo}`,
      html,
      tipoLog: 'RESET_SENHA',
      codigoDebug: codigo
    });
  }

  /**
   * 3. Envio de Comprovante / Voucher de Reserva
   */
  public static async enviarComprovanteReserva(
    para: string,
    nome: string,
    dados: ComprovanteEmailData
  ): Promise<boolean> {
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F8FAFC; margin: 0; padding: 20px; }
          .container { max-width: 560px; margin: 0 auto; background: #FFFFFF; border-radius: 12px; border: 1px solid #E2E8F0; overflow: hidden; }
          .header { background: #0F172A; padding: 24px; text-align: center; }
          .header h1 { color: #FFFFFF; font-size: 20px; margin: 0; letter-spacing: 0.5px; }
          .content { padding: 24px; }
          .voucher-box { background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 10px; padding: 20px; margin: 20px 0; }
          .voucher-code { background: #FFFFFF; border: 1px dashed #CBD5E1; border-radius: 8px; padding: 12px; text-align: center; font-family: monospace; font-size: 16px; font-weight: bold; color: #0F172A; margin-top: 12px; }
          .footer { background: #F8FAFC; padding: 16px; text-align: center; border-top: 1px solid #E2E8F0; font-size: 11px; color: #94A3B8; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>SeatMap Internal</h1>
          </div>
          <div class="content">
            <h2 style="margin: 0 0 8px 0; color: #1E293B; font-size: 18px;">Comprovante Digital de Reserva</h2>
            <p style="color: #475569; font-size: 14px; margin: 0;">Olá, <strong>${nome}</strong>! Sua reserva de assento foi confirmada com sucesso.</p>

            <div class="voucher-box">
              <table style="width: 100%; border-collapse: collapse;">
                <tr style="border-bottom: 1px solid #E2E8F0;">
                  <td style="padding: 8px 0; color: #64748B; font-size: 13px;">Data da Reserva:</td>
                  <td style="padding: 8px 0; color: #0F172A; font-weight: bold; text-align: right; font-size: 13px;">${dados.dataReserva}</td>
                </tr>
                <tr style="border-bottom: 1px solid #E2E8F0;">
                  <td style="padding: 8px 0; color: #64748B; font-size: 13px;">Escritório:</td>
                  <td style="padding: 8px 0; color: #0F172A; font-weight: 600; text-align: right; font-size: 13px;">${dados.escritorioNome} (${dados.escritorioCidade})</td>
                </tr>
                ${dados.baiaNome ? `
                <tr style="border-bottom: 1px solid #E2E8F0;">
                  <td style="padding: 8px 0; color: #64748B; font-size: 13px;">Baia / Setor:</td>
                  <td style="padding: 8px 0; color: #0F172A; font-weight: 600; text-align: right; font-size: 13px;">${dados.baiaNome}</td>
                </tr>` : ''}
                <tr style="border-bottom: 1px solid #E2E8F0;">
                  <td style="padding: 8px 0; color: #64748B; font-size: 13px;">Mesa Selecionada:</td>
                  <td style="padding: 8px 0; color: #16A34A; font-weight: bold; text-align: right; font-size: 14px;">Mesa ${dados.cadeiraIdentificador}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; color: #64748B; font-size: 13px;">Emissão:</td>
                  <td style="padding: 8px 0; color: #64748B; text-align: right; font-size: 12px;">${dados.emitidoEm || new Date().toLocaleString('pt-BR')}</td>
                </tr>
              </table>

              <div style="margin-top: 16px; text-align: center;">
                <span style="font-size: 11px; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px;">Autenticador do Comprovante</span>
                <div class="voucher-code">${dados.codigoComprovante}</div>
              </div>
            </div>

            <p style="font-size: 12px; color: #64748B; line-height: 1.4; margin: 0;">
              Lembre-se de realizar a confirmação diária de presença (Check-in) no aplicativo no dia reservado entre as 06:00 e 11:00 para garantir a ocupação do seu assento.
            </p>
          </div>
          <div class="footer">
            © ${new Date().getFullYear()} SeatMap Corporate. Mensagem automática, não responda.
          </div>
        </div>
      </body>
      </html>
    `;

    return this.despacharEmail({
      to: para,
      subject: `[SeatMap] Comprovante de Reserva - Mesa ${dados.cadeiraIdentificador} (${dados.dataReserva})`,
      html,
      tipoLog: 'COMPROVANTE_RESERVA',
      codigoDebug: dados.codigoComprovante
    });
  }

  /**
   * Despachador assíncrono seguro com logs e tratamento de erros
   */
  private static async despacharEmail(opts: {
    to: string;
    subject: string;
    html: string;
    tipoLog: string;
    codigoDebug?: string;
  }): Promise<boolean> {
    try {
      const transporter = this.getTransporter();
      const mailOptions = {
        from: this.getFromAddress(),
        to: opts.to,
        subject: opts.subject,
        html: opts.html
      };

      const info = await transporter.sendMail(mailOptions);

      console.log('================================================================');
      console.log(`[EmailService] E-mail enviado com sucesso!`);
      console.log(`[EmailService] Tipo: [${opts.tipoLog}] Destinatário: ${opts.to}`);
      console.log(`[EmailService] Assunto: ${opts.subject}`);
      if (opts.codigoDebug) {
        console.log(`[EmailService] Código/Token: >>> ${opts.codigoDebug} <<<`);
      }
      if (info.messageId) {
        console.log(`[EmailService] MessageId: ${info.messageId}`);
      }
      console.log('================================================================');

      return true;
    } catch (error) {
      console.error(`[EmailService Error] Falha ao despachar e-mail para ${opts.to}:`, error);
      return false;
    }
  }
}
