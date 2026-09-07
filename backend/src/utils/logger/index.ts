import { LogContext, LogEntry, LoggerOptions, LogFormatter, LogLevel, LogTransport } from './types';
import { JsonFormatter, DevFormatter } from './formatters';
import { ConsoleTransport, MemoryTransport, StreamTransport } from './transports';
import { redactSensitiveData } from './redactor';

const LEVEL_PRIORITIES: Record<LogLevel, number> = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40
};

export class Logger {
  private level: LogLevel;
  private service: string;
  private environment: string;
  private formatter: LogFormatter;
  private transports: LogTransport[];
  private defaultContext: LogContext;

  constructor(options?: LoggerOptions) {
    this.level = options?.level || (process.env.LOG_LEVEL as LogLevel) || 'info';
    this.service = options?.service || process.env.SERVICE_NAME || 'seatmap-backend';
    this.environment = options?.environment || process.env.NODE_ENV || 'development';
    
    // Em produção ou se configurado, usa JSON (SIEM standard); em dev local pode usar DevFormatter
    this.formatter = options?.formatter || 
      (this.environment === 'development' && process.env.LOG_FORMAT !== 'json' 
        ? new DevFormatter() 
        : new JsonFormatter());

    this.transports = options?.transports || [new ConsoleTransport()];
    this.defaultContext = options?.defaultContext || {};
  }

  public shouldLog(level: LogLevel): boolean {
    return LEVEL_PRIORITIES[level] >= LEVEL_PRIORITIES[this.level];
  }

  public child(context: LogContext): Logger {
    return new Logger({
      level: this.level,
      service: this.service,
      environment: this.environment,
      formatter: this.formatter,
      transports: this.transports,
      defaultContext: { ...this.defaultContext, ...context }
    });
  }

  public addTransport(transport: LogTransport): this {
    this.transports.push(transport);
    return this;
  }

  public setLevel(level: LogLevel): this {
    this.level = level;
    return this;
  }

  public log(level: LogLevel, message: string, context?: LogContext, error?: Error): void {
    if (!this.shouldLog(level)) return;

    const mergedContext = {
      ...this.defaultContext,
      ...context
    };

    const correlationId = mergedContext.correlationId || this.defaultContext.correlationId;

    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      service: this.service,
      environment: this.environment,
      correlationId,
      context: Object.keys(mergedContext).length > 0 ? mergedContext : undefined,
      error: error
        ? {
            name: error.name,
            message: error.message,
            stack: error.stack
          }
        : undefined
    };

    const formatted = this.formatter.format(entry);

    for (const transport of this.transports) {
      try {
        transport.log(formatted, entry);
      } catch (err) {
        // Fallback defensivo para não quebrar a aplicação caso um transport falhe
        process.stderr.write(`[LOGGER TRANSPORT FAILURE]: ${err}\n`);
      }
    }
  }

  public debug(message: string, context?: LogContext): void {
    this.log('debug', message, context);
  }

  public info(message: string, context?: LogContext): void {
    this.log('info', message, context);
  }

  public warn(message: string, context?: LogContext, error?: Error): void {
    this.log('warn', message, context, error);
  }

  public error(message: string, errorOrContext?: Error | LogContext, context?: LogContext): void {
    if (errorOrContext instanceof Error) {
      this.log('error', message, context, errorOrContext);
    } else {
      this.log('error', message, errorOrContext);
    }
  }
}

// Instância Singleton padrão
export const logger = new Logger();

export * from './types';
export * from './redactor';
export * from './formatters';
export * from './transports';
export default logger;

