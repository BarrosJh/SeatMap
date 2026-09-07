import { Writable } from 'stream';
import { LogEntry, LogTransport } from './types';

export class ConsoleTransport implements LogTransport {
  log(formattedMessage: string, entry: LogEntry): void {
    if (entry.level === 'error') {
      process.stderr.write(formattedMessage + '\n');
    } else {
      process.stdout.write(formattedMessage + '\n');
    }
  }
}

export class MemoryTransport implements LogTransport {
  public entries: { formattedMessage: string; entry: LogEntry }[] = [];

  log(formattedMessage: string, entry: LogEntry): void {
    this.entries.push({ formattedMessage, entry });
  }

  clear(): void {
    this.entries = [];
  }
}

export class StreamTransport implements LogTransport {
  private stream: Writable;

  constructor(stream: Writable) {
    this.stream = stream;
  }

  log(formattedMessage: string): void {
    this.stream.write(formattedMessage + '\n');
  }
}

