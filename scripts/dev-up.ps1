<#
.SYNOPSIS
    Headless build + run for the web dev container on Windows.

.PARAMETER Workspace
    Host directory to mount at /workspace. Defaults to the current directory.

.PARAMETER NoBuild
    Skip `docker build` and just run the existing image.

.PARAMETER NoPull
    Skip `--pull` (offline / pinned builds).

.PARAMETER Rebuild
    Force `docker build --no-cache` for a clean rebuild.

.EXAMPLE
    .\scripts\dev-up.ps1
    .\scripts\dev-up.ps1 -Workspace C:\code\my-site
    .\scripts\dev-up.ps1 -Rebuild
#>
[CmdletBinding()]
param(
    [string]$Workspace    = (Get-Location).Path,
    [string]$ImageName    = "dev-template-web",
    [string]$ContainerName = "dev-web",
    [switch]$NoBuild,
    [switch]$NoPull,
    [switch]$Rebuild
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not $NoBuild) {
    $buildFlags = @()
    if (-not $NoPull) { $buildFlags += "--pull" }
    if ($Rebuild)     { $buildFlags += "--no-cache" }
    docker build @buildFlags -t $ImageName $repoRoot
    if ($LASTEXITCODE -ne 0) { throw "docker build failed" }
}

$claudeJson = Join-Path $env:USERPROFILE ".claude.json"
$claudeDir  = Join-Path $env:USERPROFILE ".claude"

if (-not (Test-Path $claudeJson)) {
    Write-Warning "$claudeJson not found. Run 'claude' on the host at least once."
}
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir | Out-Null
}

$dockerArgs = @(
    "run", "--rm", "-it",
    "--name", $ContainerName,
    "--init",
    "-v", "${Workspace}:/workspace",
    "-v", "${claudeJson}:/host-claude-auth.json",
    "-v", "${claudeDir}:/host-claude-dir",
    # Expose typical web dev ports
    "-p", "3000:3000",
    "-p", "5173:5173",
    "-p", "8000:8000",
    "-p", "8080:8080",
    # Docker Desktop SSH agent forwarding
    "-v", "/run/host-services/ssh-auth.sock:/ssh-agent",
    "-e", "SSH_AUTH_SOCK=/ssh-agent",
    $ImageName
)

& docker @dockerArgs
