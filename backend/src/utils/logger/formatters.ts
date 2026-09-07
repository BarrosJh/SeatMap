import { LogEntry, LogFormatter } from './types';
import { redactSensitiveData } from './redactor';

export class JsonFormatter implements LogFormatter {
  format(entry: LogEntry): string {
    const sanitizedEntry = {
      timestamp: entry.timestamp,
      level: entry.level.toUpperCase(),
      service: entry.service,
      environment: entry.environment,
      correlationId: entry.correlationId,
      message: entry.message,
      context: entry.context ? redactSensitiveData(entry.context) : undefined,
      error: entry.error
    };

    // Remove campos undefined para manter JSON limpo
    return JSON.stringify(sanitizedEntry);
  }
}

export class DevFormatter implements LogFormatter {
  format(entry: LogEntry): string {
    const time = entry.timestamp.split('T')[1] || entry.timestamp;
    const cid = entry.correlationId ? ` [CID:${entry.correlationId.substring(0, 8)}]` : '';
    const ctx = entry.context ? ` ${JSON.stringify(redactSensitiveData(entry.context))}` : '';
    const err = entry.error ? `\n  Error: ${entry.error.message}\n${entry.error.stack}` : '';
    
    return `[${time}] [${entry.level.toUpperCase()}]${cid} ${entry.message}${ctx}${err}`;
  }
}

