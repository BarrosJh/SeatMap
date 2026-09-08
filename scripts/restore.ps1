[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$BackupFile,
    [string]$DbHost = $(if ($env:DB_HOST) { $env:DB_HOST } else { "localhost" }),
    [int]$DbPort = $(if ($env:DB_PORT) { [int]$env:DB_PORT } else { 5432 }),
    [string]$DbUser = $(if ($env:DB_USER) { $env:DB_USER } else { "seatmap_user" }),
    [string]$DbName = $(if ($env:DB_NAME) { $env:DB_NAME } else { "seatmap_db" }),
    [string]$DbPassword = $env:DB_PASSWORD,
    [switch]$ConfirmRestore
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BackupFile)) { throw "Backup nao encontrado: $BackupFile" }
if (-not $ConfirmRestore) { throw "Restore bloqueado. Use -ConfirmRestore explicitamente." }

$pgTools = Get-Command psql -ErrorAction SilentlyContinue
if (-not $pgTools) { throw "psql nao encontrado no PATH." }
$gzipTool = Get-Command gzip -ErrorAction SilentlyContinue
if (-not $gzipTool) { throw "gzip nao encontrado no PATH." }

$checksumFile = "${BackupFile}.sha256"
if (-not (Test-Path $checksumFile)) { throw "Arquivo de checksum ausente: $checksumFile" }

$expected = (Get-Content $checksumFile | Select-Object -First 1).Split(' ')[0].Trim().ToUpperInvariant()
$actual = (Get-FileHash -Path $BackupFile -Algorithm SHA256).Hash.ToUpperInvariant()
if ($expected -ne $actual) { throw "Checksum invalido. Restore cancelado." }

if ($DbPassword) { $env:PGPASSWORD = $DbPassword }

Write-Host "[*] Validando compressao do backup..."
& $gzipTool.Source -t $BackupFile

Write-Host "[*] Restaurando $BackupFile em ${DbName}@${DbHost}:${DbPort}..."
& $gzipTool.Source -dc $BackupFile | & $pgTools.Source `
    --host $DbHost `
    --port $DbPort `
    --username $DbUser `
    --dbname $DbName `
    --set ON_ERROR_STOP=1 `
    --single-transaction

Write-Host "[*] Executando verificacao pos-restore..."
$verification = @"
SELECT current_database() AS database,
       (SELECT COUNT(*) FROM usuarios) AS usuarios,
       (SELECT COUNT(*) FROM reservas) AS reservas,
       (SELECT COUNT(*) FROM auditoria_acessos) AS auditoria_acessos;
"@
$verification | & $pgTools.Source --host $DbHost --port $DbPort --username $DbUser --dbname $DbName --set ON_ERROR_STOP=1

Write-Host "[+] Restore concluido e verificacao pos-restore executada." -ForegroundColor Green


