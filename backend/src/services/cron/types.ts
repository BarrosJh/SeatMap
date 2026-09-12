export interface JobExecutionResult {
  totalProcessadas: number;
  detalhes?: any[];
}

export interface NoShowExecutionResult {
  totalExpiradas: number;
  reservas: any[];
}

export interface AutoConclusionExecutionResult {
  totalConcluidas: number;
  reservas: any[];
}

