# ==============================================================================
# SeatMap PostgreSQL Restore Script for PowerShell (Windows Server / Dev)
# ==============================================================================
# Restaura um arquivo de backup (.sql.gz ou .sql) no banco de dados PostgreSQL
# após validação de integridade SHA256 do arquivo.
#
# Uso:
#   .\scripts\restore.ps1 -BackupFile "backups\seatmap_backup_20260907_120000.sql.gz"
# ==============================================================================

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$BackupFile,

    [string]$DbHost = $env:DB_HOST,
    [int]$DbPort = $(if ($env:DB_PORT) { [int]$env:DB_PORT } else { 5432 }),
    [string]$DbUser = $(if ($env:DB_USER) { $env:DB_USER } else { "postgres" }),
    [string]$DbName = $(if ($env:DB_NAME) { $env:DB_NAME } else { "seatmap" }),
    [string]$DbPassword = $env:DB_PASSWORD
)

$ErrorActionPreference = "Stop"

if (-not $DbHost) { $DbHost = "localhost" }
if (-not (Test-Path $BackupFile)) {
    Write-Error "[-] ERRO: Arquivo de backup '$BackupFile' não foi encontrado."
    exit 1
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " [SeatMap] Iniciando Processo de Restauração do PostgreSQL (PowerShell)" -ForegroundColor Cyan
Write-Host " Data/Hora : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host " Arquivo   : ${BackupFile}"
Write-Host " Host      : ${DbHost}:${DbPort}"
Write-Host " Banco     : ${DbName}"
Write-Host "================================================================================" -ForegroundColor Cyan

# Verificação de Checksum se existir .sha256
$ChecksumFile = "${BackupFile}.sha256"
if (Test-Path $ChecksumFile) {
    Write-Host "[*] Validando integridade do backup com arquivo de Checksum..." -ForegroundColor Yellow
    $ExpectedHash = (Get-Content $ChecksumFile | Select-Object -First 1).Split(" ")[0].Trim()
    $ActualHash = (Get-FileHash -Path $BackupFile -Algorithm SHA256).Hash.Trim()

    if ($ExpectedHash.ToUpper() -eq $ActualHash.ToUpper()) {
        Write-Host "[+] Checksum SHA-256 verificado com sucesso!" -ForegroundColor Green
    } else {
        Write-Error "[-] ERRO CRÍTICO: Checksum SHA-256 divergente! O arquivo pode estar corrompido."
        exit 1
    }
}

# Localiza utilitário psql
$psqlCmd = Get-Command "psql" -ErrorAction SilentlyContinue
if (-not $psqlCmd) {
    $pgPathDefault = "C:\Program Files\PostgreSQL\*\bin\psql.exe"
    $foundPg = Resolve-Path $pgPathDefault -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($foundPg) {
        $psqlExe = $foundPg.Path
    } else {
        Write-Error "[-] ERRO: 'psql' não encontrado no PATH ou em Program Files\PostgreSQL."
        exit 1
    }
} else {
    $psqlExe = "psql"
}

if ($DbPassword) {
    $env:PGPASSWORD = $DbPassword
}

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    # Descompacta se for .gz
    $SqlToExecute = $BackupFile
    $TempUnzipped = $null

    if ($BackupFile.EndsWith(".gz", [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "[*] Descompactando arquivo GZip em memória temporária..." -ForegroundColor Yellow
        $TempUnzipped = [System.IO.Path]::GetTempFileName() + ".sql"
        
        $inputStream = [System.IO.File]::OpenRead($BackupFile)
        $gzipStream = New-Object System.IO.Compression.GZipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)
        $outputStream = [System.IO.File]::Create($TempUnzipped)
        $gzipStream.CopyTo($outputStream)
        $outputStream.Dispose()
        $gzipStream.Dispose()
        $inputStream.Dispose()

        $SqlToExecute = $TempUnzipped
    }

    Write-Host "[*] Encerrando conexões ativas no banco $DbName..." -ForegroundColor Yellow
    try {
        & $psqlExe -h $DbHost -p $DbPort -U $DbUser -d "postgres" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DbName' AND pid <> pg_backend_pid();" | Out-Null
    } catch {
        Write-Host "    [!] Aviso: Não foi possível terminar sessões automaticamente." -ForegroundColor DarkGray
    }

    Write-Host "[*] Executando restore do banco $DbName via psql..." -ForegroundColor Yellow
    & $psqlExe -h $DbHost -p $DbPort -U $DbUser -d $DbName -f $SqlToExecute

    if ($TempUnzipped -and (Test-Path $TempUnzipped)) {
        Remove-Item $TempUnzipped -Force
    }

    $Stopwatch.Stop()
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host " [SeatMap] Restauração Concluída com Sucesso em $($Stopwatch.Elapsed.TotalSeconds.ToString('F2'))s!" -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Cyan
    exit 0
} catch {
    Write-Error "[-] Falha crítica durante restauração: $_"
    if ($TempUnzipped -and (Test-Path $TempUnzipped)) { Remove-Item $TempUnzipped -Force }
    exit 1
}

