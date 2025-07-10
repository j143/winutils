<#
.SYNOPSIS
   Hadoop Windows Native Libraries Setup Script

.DESCRIPTION
   This script automates the installation of Hadoop native libraries (winutils.exe and hadoop.dll)
   required for running Hadoop-based applications on Windows systems.

.PARAMETER HadoopVersion
   Specifies the Hadoop version to download. Default is "3.3.6"

.PARAMETER InstallPath
   Specifies the installation directory. Default is "C:\hadoop"

.EXAMPLE
   .\setup-hadoop-windows.ps1
   .\setup-hadoop-windows.ps1 -HadoopVersion "3.3.6" -InstallPath "D:\tools\hadoop"

.NOTES
   Author: Janardhan Pulivarthi
   Version: 1.0
   Created: 2025-07-10
   AI Tool: Claude AI is used for generating the first draft for this code
   
   PRODUCTION READINESS CONSIDERATIONS:
   ====================================
   
   1. SECURITY & VALIDATION:
      - Downloads from GitHub repository (j143/winutils) - consider hosting internally
      - No file hash validation implemented - add SHA256 checksum verification in production
      - Requires Administrator privileges - implement proper privilege escalation handling
      - No digital signature verification - validate file authenticity before execution
   
   2. ERROR HANDLING & RESILIENCE:
      - Basic retry logic for failed downloads - expand for production robustness
      - Limited network error handling - implement comprehensive connection failure recovery
      - No rollback mechanism - add ability to revert changes if installation fails
      - Missing detailed logging - implement structured logging for audit trails
   
   3. ENVIRONMENT CONSIDERATIONS:
      - Modifies system-wide environment variables - consider user-scope alternatives
      - No conflict detection with existing Hadoop installations
      - Limited version compatibility checking - validate against target application requirements
      - No cleanup of temporary files or failed installations
   
   4. ENTERPRISE DEPLOYMENT:
      - Consider using package managers (Chocolatey, Scoop) for standardized deployment
      - Implement configuration management integration (DSC, Ansible, etc.)
      - Add support for silent/unattended installation modes
      - Include version inventory and compliance reporting
   
   5. MONITORING & MAINTENANCE:
      - No health checks or validation tests post-installation
      - Missing update mechanism for newer versions
      - No integration with monitoring systems
      - Limited diagnostic information for troubleshooting
   
   6. RECOMMENDED PRODUCTION ENHANCEMENTS:
      - Implement comprehensive input validation and sanitization
      - Add configuration file support for deployment parameters
      - Include dependency checking (Java version, OS compatibility)
      - Add support for proxy environments and air-gapped networks
      - Implement proper exit codes and status reporting
      - Add integration with enterprise software distribution systems
   
   7. COMPLIANCE & GOVERNANCE:
      - Document software licensing implications
      - Implement change management integration
      - Add approval workflows for production deployments
      - Include security scanning and vulnerability assessment
   
   USE AT YOUR OWN RISK: This script is provided as-is for development and testing purposes.
   Thorough testing and security review are required before production deployment.

.LINK
   https://github.com/j143/winutils
   https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/NativeLibraries.html
#>

# Hadoop Windows Setup Script
param(
    [string]$HadoopVersion = "3.3.6",
    [string]$InstallPath = "C:\hadoop"
)

# Function to download files
function Download-File {
    param($Url, $OutFile)
    try {
        Write-Host "Downloading $OutFile..." -ForegroundColor Green
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
        return $true
    }
    catch {
        Write-Host "Failed to download $OutFile : $_" -ForegroundColor Red
        return $false
    }
}

# Function to add to PATH if not already present
function Add-ToPath {
    param($PathToAdd)
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($currentPath -notlike "*$PathToAdd*") {
        Write-Host "Adding $PathToAdd to system PATH..." -ForegroundColor Yellow
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$PathToAdd", "Machine")
        $env:PATH += ";$PathToAdd"
    }
}

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "Setting up Hadoop native libraries for Windows..." -ForegroundColor Cyan

# Create installation directory
if (!(Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Write-Host "Created directory: $InstallPath" -ForegroundColor Green
}

$binPath = Join-Path $InstallPath "bin"
if (!(Test-Path $binPath)) {
    New-Item -ItemType Directory -Path $binPath -Force | Out-Null
}

# Download winutils and hadoop.dll from the winutils repository
$winutilsUrl = "https://github.com/j143/winutils/raw/master/hadoop-$HadoopVersion/bin/winutils.exe"
$hadoopDllUrl = "https://github.com/j143/winutils/raw/master/hadoop-$HadoopVersion/bin/hadoop.dll"

$winutilsPath = Join-Path $binPath "winutils.exe"
$hadoopDllPath = Join-Path $binPath "hadoop.dll"

# Download files
$winutilsSuccess = Download-File -Url $winutilsUrl -OutFile $winutilsPath
$hadoopDllSuccess = Download-File -Url $hadoopDllUrl -OutFile $hadoopDllPath

if (!$winutilsSuccess -or !$hadoopDllSuccess) {
    Write-Host "Failed to download required files. Trying alternative version..." -ForegroundColor Yellow
    
    # Try with a different version if the specified one fails
    $altVersion = "3.3.4"
    $winutilsUrl = "https://github.com/j143/winutils/raw/master/hadoop-$altVersion/bin/winutils.exe"
    $hadoopDllUrl = "https://github.com/j143/winutils/raw/master/hadoop-$altVersion/bin/hadoop.dll"
    
    $winutilsSuccess = Download-File -Url $winutilsUrl -OutFile $winutilsPath
    $hadoopDllSuccess = Download-File -Url $hadoopDllUrl -OutFile $hadoopDllPath
    
    if (!$winutilsSuccess -or !$hadoopDllSuccess) {
        Write-Host "Failed to download from alternative version. Please check your internet connection or try manually." -ForegroundColor Red
        exit 1
    }
}

# Set environment variables
Write-Host "Setting environment variables..." -ForegroundColor Yellow
[Environment]::SetEnvironmentVariable("HADOOP_HOME", $InstallPath, "Machine")
[Environment]::SetEnvironmentVariable("HADOOP_CONF_DIR", (Join-Path $InstallPath "etc\hadoop"), "Machine")
$env:HADOOP_HOME = $InstallPath

# Add to PATH
Add-ToPath -PathToAdd $binPath

# Create etc/hadoop directory for configuration
$etcHadoop = Join-Path $InstallPath "etc\hadoop"
if (!(Test-Path $etcHadoop)) {
    New-Item -ItemType Directory -Path $etcHadoop -Force | Out-Null
}

# Create a basic core-site.xml to avoid warnings
$coreSiteXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>file:///</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>$InstallPath/tmp</value>
    </property>
</configuration>
"@

$coreSiteXml | Out-File -FilePath (Join-Path $etcHadoop "core-site.xml") -Encoding UTF8

# Create tmp directory
$tmpDir = Join-Path $InstallPath "tmp"
if (!(Test-Path $tmpDir)) {
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
}

# Test the installation
Write-Host "Testing installation..." -ForegroundColor Yellow
try {
    & "$winutilsPath" ls $tmpDir
    Write-Host "✓ Hadoop native libraries installed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "⚠ Installation completed but test failed. You may need to restart your IDE/terminal." -ForegroundColor Yellow
}

Write-Host @"

Installation Complete!
===================
HADOOP_HOME: $InstallPath
Binary Path: $binPath
Configuration: $etcHadoop

Environment variables have been set system-wide.
You may need to restart your IDE or terminal to pick up the new PATH.

To verify the installation works in a new PowerShell window, run:
winutils.exe ls C:\

"@ -ForegroundColor Cyan

# Optional: Create a batch file for easy JVM arguments
$jvmArgsFile = Join-Path $InstallPath "jvm-args.txt"
$jvmArgs = @"
-Dhadoop.home.dir=$InstallPath
-Djava.library.path=$binPath
-Dhadoop.native.lib=true
"@
$jvmArgs | Out-File -FilePath $jvmArgsFile -Encoding UTF8

Write-Host "JVM arguments saved to: $jvmArgsFile" -ForegroundColor Green
Write-Host "You can use these in your IDE run configuration if needed." -ForegroundColor Green
