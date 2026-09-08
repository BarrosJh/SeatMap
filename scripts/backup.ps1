# ==============================================================================
# SeatMap PostgreSQL Backup Script for PowerShell (Windows Server / Dev)
# ==============================================================================
# Executa rotina diária de pg_dump com compressão gzip / zip, checksum SHA256 e
# exclusão automática de arquivos de backup com mais de 30 dias (política de retenção).
#
# Uso:
#   .\scripts\backup.ps1
#   .\scripts\backup.ps1 -DbHost "localhost" -DbPort 5432 -DbName "seatmap" -RetentionDays 30
# ==============================================================================

[CmdletBinding()]
param (
    [string]$DbHost = $env:DB_HOST,
    [int]$DbPort = $(if ($env:DB_PORT) { [int]$env:DB_PORT } else { 5432 }),
    [string]$DbUser = $(if ($env:DB_USER) { $env:DB_USER } else { "seatmap_user" }),
    [string]$DbName = $(if ($env:DB_NAME) { $env:DB_NAME } else { "seatmap_db" }),
    [string]$DbPassword = $env:DB_PASSWORD,
    [string]$BackupDir = $(Join-Path $PSScriptRoot "..\backups"),
    [int]$RetentionDays = 30
)

$ErrorActionPreference = "Stop"

if (-not $DbHost) { $DbHost = "localhost" }
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupFileName = "seatmap_backup_${Timestamp}.sql"
$BackupFilePath = Join-Path $BackupDir $BackupFileName
$GzFilePath = "${BackupFilePath}.gz"
$ChecksumFilePath = "${GzFilePath}.sha256"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " [SeatMap] Iniciando Rotina de Backup do PostgreSQL (PowerShell)" -ForegroundColor Cyan
Write-Host " Data/Hora : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host " Host      : ${DbHost}:${DbPort}"
Write-Host " Banco     : ${DbName}"
Write-Host " Destino   : ${GzFilePath}"
Write-Host " Retenção  : ${RetentionDays} dias"
Write-Host "================================================================================" -ForegroundColor Cyan

# Verifica se pg_dump está acessível
$pgDumpCmd = Get-Command "pg_dump" -ErrorAction SilentlyContinue
if (-not $pgDumpCmd) {
    # Tenta localizar no diretório padrão do PostgreSQL no Windows
    $pgPathDefault = "C:\Program Files\PostgreSQL\*\bin\pg_dump.exe"
    $foundPg = Resolve-Path $pgPathDefault -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($foundPg) {
        $pgDumpExe = $foundPg.Path
    } else {
        Write-Error "[-] ERRO: 'pg_dump' não encontrado no PATH ou em Program Files\PostgreSQL."
        exit 1
    }
} else {
    $pgDumpExe = "pg_dump"
}

# Configura senha para a sessão
if ($DbPassword) {
    $env:PGPASSWORD = $DbPassword
}

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "[*] Executando pg_dump..." -ForegroundColor Yellow

try {
    & $pgDumpExe -h $DbHost -p $DbPort -U $DbUser -d $DbName `
        --format=plain `
        --no-owner `
        --no-acl `
        --clean `
        --if-exists `
        --file=$BackupFilePath

    if (-not (Test-Path $BackupFilePath) -or ((Get-Item $BackupFilePath).Length -eq 0)) {
        throw "O arquivo gerado por pg_dump está vazio ou não foi criado."
    }

    Write-Host "[*] Comprimindo arquivo de dump com GZip..." -ForegroundColor Yellow
    # Compressão nativa em GZip via .NET
    $inputStream = [System.IO.File]::OpenRead($BackupFilePath)
    $outputStream = [System.IO.File]::Create($GzFilePath)
    $gzipStream = New-Object System.IO.Compression.GZipStream($outputStream, [System.IO.Compression.CompressionLevel]::Optimal)
    $inputStream.CopyTo($gzipStream)
    $gzipStream.Dispose()
    $outputStream.Dispose()
    $inputStream.Dispose()

    # Remove o SQL não compactado
    Remove-Item $BackupFilePath -Force

    $Stopwatch.Stop()
    $FileSizeKb = [math]::Round(((Get-Item $GzFilePath).Length / 1KB), 2)
    Write-Host "[+] Backup comprimido com sucesso em $($Stopwatch.Elapsed.TotalSeconds.ToString('F2'))s! Tamanho: ${FileSizeKb} KB" -ForegroundColor Green

    # Checksum SHA-256
    Write-Host "[*] Calculando Checksum SHA-256..." -ForegroundColor Yellow
    $Hash = (Get-FileHash -Path $GzFilePath -Algorithm SHA256).Hash
    Set-Content -Path $ChecksumFilePath -Value "$Hash  $([System.IO.Path]::GetFileName($GzFilePath))"
    Write-Host "[+] Checksum SHA256: $Hash" -ForegroundColor Green

    # Política de Retenção
    Write-Host "[*] Aplicando política de retenção (arquivos com mais de $RetentionDays dias)..." -ForegroundColor Yellow
    $CutoffDate = (Get-Date).AddDays(-$RetentionDays)
    $OldFiles = Get-ChildItem -Path $BackupDir -Filter "seatmap_backup_*.sql.gz*" | Where-Object { $_.LastWriteTime -lt $CutoffDate }
    
    $PurgedCount = 0
    foreach ($file in $OldFiles) {
        Write-Host "    [-] Removendo backup expirado: $($file.Name)" -ForegroundColor DarkGray
        Remove-Item $file.FullName -Force
        $PurgedCount++
    }
    Write-Host "[+] Retenção concluída: $PurgedCount arquivo(s) expirado(s) removido(s)." -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host " [SeatMap] Processo de Backup Finalizado com Sucesso!" -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Cyan
    exit 0
} catch {
    Write-Error "[-] Falha crítica durante rotina de backup: $_"
    if (Test-Path $BackupFilePath) { Remove-Item $BackupFilePath -Force }
    exit 1
}

