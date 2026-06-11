#!/usr/bin/env pwsh
#Requires -Version 7.0

param(
    [ValidateSet("all", "bots1", "bots2", "bots3")]
    [string]$Profile = "all"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $PSCommandPath
Set-Location $ScriptDir

# ---- BOTSv1 apps ----
$Bots1Apps = @(
    "fortinet-fortigate-add-on-for-splunk_13.tgz"
    "splunk-add-on-for-microsoft-sysmon_810.tgz"
    "splunk-add-on-for-microsoft-windows_800.tgz"
    "splunk-app-for-stream_720-stripped.tgz"
    "splunk-ta-for-suricata_233.tgz"
    "url-toolbox_192.tgz"
    "splunk-add-on-for-tenable_514.tgz"
    "boss-of-the-soc-bots-investigation-workshop-for-splunk_122.tgz"
)

# ---- BOTSv2 apps ----
$Bots2Apps = @(
    "base64_11.tgz"
    "jellyfisher_101.tgz"
    "palo-alto-networks-add-on-for-splunk_811.tgz"
    "sa-investigator-for-enterprise-security_400.tgz"
    "splunk-add-on-for-apache-web-server_210.tgz"
    "splunk-add-on-for-microsoft-cloud-services_522.tgz"
    "splunk-add-on-for-microsoft-sysmon_810.tgz"
    "splunk-add-on-for-microsoft-windows_880.tgz"
    "splunk-add-on-for-symantec-endpoint-protection_341.tgz"
    "splunk-add-on-for-unix-and-linux_850.tgz"
    "splunk-app-for-osquery_10.tgz"
    "splunk-app-for-stream_720-stripped.tgz"
    "splunk-common-information-model-cim_4180.tgz"
    "splunk-security-essentials_371.tgz"
    "splunk-ta-for-suricata_233.tgz"
    "ssl-certificate-checker_420.tgz"
    "url-toolbox_192.tgz"
    "website-monitoring_294.tgz"
    "boss-of-the-soc-bots-advanced-apt-hunting-companion-app-for-splunk_11.tgz"
    "splunk-add-on-for-microsoft-iis_130.tgz"
)

# ---- BOTSv3 apps ----
$Bots3Apps = @(
    "amazon-guardduty-add-on-for-splunk_104.tgz"
    "cisco-endpoint-security-analytics-cesa_406.tgz"
    "code42-for-splunk-legacy_3012.tgz"
    "decrypt_231.tgz"
    "microsoft-365-app-for-splunk_331.tgz"
    "osquery-app-for-splunk_060.tgz"
    "sa-cim_vladiator_200.tgz"
    "splunk-add-on-for-amazon-web-services-aws_730.tgz"
    "splunk-add-on-for-cisco-asa_511.tgz"
    "splunk-add-on-for-microsoft-azure_403.tgz"
    "splunk-add-on-for-microsoft-cloud-services_522.tgz"
    "splunk-add-on-for-microsoft-office-365_430.tgz"
    "splunk-add-on-for-microsoft-office-365-reporting-web-service_201.tgz"
    "splunk-add-on-for-microsoft-sysmon_1062.tgz"
    "splunk-add-on-for-microsoft-windows_880.tgz"
    "splunk-add-on-for-symantec-endpoint-protection_341.tgz"
    "splunk-add-on-for-tenable_514.tgz"
    "splunk-add-on-for-unix-and-linux_850.tgz"
    "splunk-app-for-stream_811.tgz"
    "splunk-common-information-model-cim_4180.tgz"
    "splunk-es-content-update_4300.tgz"
    "splunk-security-essentials_371.tgz"
    "ta-for-code42-app-for-splunk_3012.tgz"
    "url-toolbox_192.tgz"
    "virustotal-workflow-actions-for-splunk_020.tgz"
)

function Write-Info   { Write-Host "[*] $($args[0])" -ForegroundColor Cyan }
function Write-Ok     { Write-Host "[+] $($args[0])" -ForegroundColor Green }
function Write-Warn   { Write-Host "[!] $($args[0])" -ForegroundColor Yellow }
function Write-Err    { Write-Host "[x] $($args[0])" -ForegroundColor Red }

function Check-Prereqs {
    $dockerPath = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerPath) {
        Write-Err "Docker is not installed. Install Docker Desktop from:"
        Write-Err "https://www.docker.com/products/docker-desktop/"
        exit 1
    }
    Write-Ok "Docker found: $(docker --version 2>&1)"

    $composeOk = $null
    try { $composeOk = docker compose version 2>&1 } catch {}
    if (-not $composeOk) {
        Write-Err "Docker Compose is not available in your Docker installation."
        exit 1
    }
    Write-Ok "Docker Compose found"
}

function Ensure-Dirs {
    foreach ($ver in @("botsv1", "botsv2", "botsv3")) {
        $null = New-Item -ItemType Directory -Force -Path "$ScriptDir\apps\$ver"
    }
    Write-Ok "Directory structure ready"
}

function Verify-Apps {
    param([string]$Version, [string[]]$Apps)

    $dest = "$ScriptDir\apps\$Version"
    $count = 0

    foreach ($app in $Apps) {
        $filepath = Join-Path $dest $app
        if (Test-Path $filepath) {
            Write-Host "  [+] $app" -ForegroundColor Green
            $count++
        } else {
            Write-Host "  [x] $app (missing — re-clone the repo)" -ForegroundColor Red
        }
    }
    Write-Host ""
    Write-Info "Found $count/$($Apps.Count) apps for $Version"
    if ($count -ne $Apps.Count) {
        Write-Err "Missing apps — please re-clone the repository to get all files."
        exit 1
    }
}

function Configure-Password {
    $envPath = "$ScriptDir\.env"
    if (Test-Path $envPath) {
        $content = Get-Content $envPath -Raw
        if ($content -match 'SPLUNK_PASSWORD=changeme') {
            Write-Warn "Default password is 'changeme'"
            $pw = Read-Host "Enter a new admin password (leave blank to keep 'changeme')"
            if ($pw) {
                if ($pw.Length -lt 8) {
                    Write-Err "Password must be at least 8 characters"
                    Configure-Password
                    return
                }
                $content = $content -replace 'SPLUNK_PASSWORD=.*', "SPLUNK_PASSWORD=$pw"
                Set-Content -Path $envPath -Value $content -NoNewline
                Write-Ok "Password updated in .env"
            }
        }
    }
}

function Start-Containers {
    param([string]$Profile)

    Write-Host ""
    Write-Info "Starting containers..."

    switch ($Profile) {
        "all"   { docker compose up -d; break }
        "bots1" { docker compose up -d bots1; break }
        "bots2" { docker compose up -d bots2; break }
        "bots3" { docker compose up -d bots3; break }
        default { Write-Err "Unknown profile"; exit 1 }
    }
}

function Show-Summary {
    $pw = "changeme"
    if (Test-Path "$ScriptDir\.env") {
        $match = Select-String -Path "$ScriptDir\.env" -Pattern 'SPLUNK_PASSWORD=(.*)'
        if ($match) { $pw = $match.Matches.Groups[1].Value }
    }

    Write-Host ""
    Write-Host "══════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  BOSS of the SOC - Docker Setup Complete" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  BOTSv1: http://localhost:8000"
    Write-Host "  BOTSv2: http://localhost:8020"
    Write-Host "  BOTSv3: http://localhost:8030"
    Write-Host ""
    Write-Host "  Username: admin"
    Write-Host "  Password: $pw"
    Write-Host ""
    Write-Warn "Note: First boot takes 5-15 minutes to download"
    Write-Warn "datasets and install apps on initial startup."
    Write-Host ""
    Write-Warn "Containers have a 30-day trial license. To reset,"
    Write-Warn "run: docker compose down && docker compose up -d"
    Write-Host ""
    Write-Info "To stop:   docker compose down"
    Write-Info "To view logs: docker compose logs -f <service>"
    Write-Host ""
}

# ── Main ──────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  BOSS of the SOC - Docker Installer         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Info "Checking prerequisites..."
Check-Prereqs

Write-Info "Setting up directories..."
Ensure-Dirs

Write-Info "Verifying BOTSv1 apps..."
Verify-Apps -Version "botsv1" -Apps $Bots1Apps

Write-Info "Verifying BOTSv2 apps..."
Verify-Apps -Version "botsv2" -Apps $Bots2Apps

Write-Info "Verifying BOTSv3 apps..."
Verify-Apps -Version "botsv3" -Apps $Bots3Apps

Configure-Password

Start-Containers -Profile $Profile

Show-Summary
