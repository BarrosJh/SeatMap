export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

export interface LogContext {
  correlationId?: string;
  userId?: string | number;
  route?: string;
  method?: string;
  statusCode?: number;
  durationMs?: number;
  ip?: string;
  service?: string;
  environment?: string;
  [key: string]: any;
}

export interface LogEntry {
  timestamp: string;
  level: string;
  message: string;
  service: string;
  environment: string;
  correlationId?: string;
  context?: LogContext;
  error?: {
    name: string;
    message: string;
    stack?: string;
  };
}

export interface LogFormatter {
  format(entry: LogEntry): string;
}

export interface LogTransport {
  log(formattedMessage: string, entry: LogEntry): void;
}

export interface LoggerOptions {
  level?: LogLevel;
  service?: string;
  environment?: string;
  formatter?: LogFormatter;
  transports?: LogTransport[];
  defaultContext?: LogContext;
}

