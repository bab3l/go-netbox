<#
.SYNOPSIS
    Generates go-netbox API client from OpenAPI spec.

.DESCRIPTION
    This script:
    1. Cleans up old generated files
    2. Copies the OpenAPI spec
    3. Runs fix-spec.py to patch the spec
    4. Runs OpenAPI Generator to generate the Go client
    5. Applies any manual patches
    6. Runs go mod tidy and goimports
    7. Optionally runs tests

.PARAMETER SkipDocker
    Skip the Docker-based code generation (useful for testing other steps)

.PARAMETER SkipPatches
    Skip applying manual patches from the patches directory

.PARAMETER GenerateTests
    Generate API test scaffolds (default: true)

.PARAMETER RunTests
    Run tests after generation (default: false)

.PARAMETER RunIntegrationTests
    Run integration tests against a real NetBox instance (default: false)
    Requires NETBOX_URL and NETBOX_API_TOKEN environment variables

.EXAMPLE
    .\generate_api.ps1
    
.EXAMPLE
    .\generate_api.ps1 -SkipDocker

.EXAMPLE
    .\generate_api.ps1 -RunTests

.EXAMPLE
    .\generate_api.ps1 -RunIntegrationTests
#>

param(
    [switch]$SkipDocker,
    [switch]$SkipPatches,
    [bool]$GenerateTests = $true,
    [switch]$RunTests,
    [switch]$RunIntegrationTests
)

$ErrorActionPreference = "Stop"

# Get the script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "Project Root: $ProjectRoot" -ForegroundColor Cyan

# Read the Netbox major version
$NetboxMajorVersion = Get-Content "$ScriptDir\netbox_major_version" -Raw
$NetboxMajorVersion = $NetboxMajorVersion.Trim()
Write-Host "NETBOX_MAJOR_VERSION: $NetboxMajorVersion" -ForegroundColor Cyan

# Create necessary folders
$folders = @(
    "$ProjectRoot\patches",
    "$ProjectRoot\openapi",
    "$ProjectRoot\api"
)
foreach ($folder in $folders) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Write-Host "Created folder: $folder" -ForegroundColor Green
    }
}

# Update config.yaml with GenerateTests setting
$configPath = "$ScriptDir\.openapi-generator\config.yaml"
if (Test-Path $configPath) {
    $configContent = Get-Content $configPath -Raw
    $apiTestsValue = if ($GenerateTests) { "true" } else { "false" }
    $configContent = $configContent -replace '(apiTests:\s*)(true|false)', "`$1$apiTestsValue"
    Set-Content -Path $configPath -Value $configContent -NoNewline
    Write-Host "Set apiTests: $apiTestsValue in config.yaml" -ForegroundColor Cyan
}

# Purge old generated files (only if we're regenerating)
if (-not $SkipDocker) {
    Write-Host "`nPurging old generated files..." -ForegroundColor Yellow
    $filesListPath = "$ProjectRoot\.openapi-generator\FILES"
    if (Test-Path $filesListPath) {
        $files = Get-Content $filesListPath
        foreach ($file in $files) {
            $filePath = Join-Path $ProjectRoot $file
            if (Test-Path $filePath) {
                Remove-Item $filePath -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "Removed $(($files | Measure-Object).Count) old generated files" -ForegroundColor Green
    }
}

# Find the OpenAPI spec file
$specFiles = Get-ChildItem "$ProjectRoot\openapi" -Filter "openapi-*.yaml" | Sort-Object Name -Descending
if ($specFiles.Count -eq 0) {
    Write-Error "No OpenAPI spec found in $ProjectRoot\openapi. Please download the spec first."
    exit 1
}

$latestSpec = $specFiles[0]
Write-Host "`nUsing OpenAPI spec: $($latestSpec.Name)" -ForegroundColor Cyan

# Copy the spec to api folder
Copy-Item $latestSpec.FullName "$ProjectRoot\api\openapi.yaml" -Force
Write-Host "Copied spec to api\openapi.yaml" -ForegroundColor Green

# Copy .openapi-generator config
if (Test-Path "$ScriptDir\.openapi-generator") {
    Copy-Item "$ScriptDir\.openapi-generator" "$ProjectRoot\.openapi-generator" -Recurse -Force
    Write-Host "Copied .openapi-generator config" -ForegroundColor Green
}
if (Test-Path "$ScriptDir\.openapi-generator-ignore") {
    Copy-Item "$ScriptDir\.openapi-generator-ignore" "$ProjectRoot\.openapi-generator-ignore" -Force
    Write-Host "Copied .openapi-generator-ignore" -ForegroundColor Green
}

# Run fix-spec.py to patch the OpenAPI spec
Write-Host "`nPatching OpenAPI spec with fix-spec.py..." -ForegroundColor Yellow
Push-Location $ScriptDir
try {
    python fix-spec.py
    if ($LASTEXITCODE -ne 0) {
        Write-Error "fix-spec.py failed with exit code $LASTEXITCODE"
        exit 1
    }
    Write-Host "OpenAPI spec patched successfully" -ForegroundColor Green
}
finally {
    Pop-Location
}

# Run OpenAPI Generator via Docker
if (-not $SkipDocker) {
    Write-Host "`nRunning OpenAPI Generator..." -ForegroundColor Yellow
    
    # Convert Windows path to Docker-compatible path
    $dockerPath = $ProjectRoot -replace '\\', '/' -replace '^([A-Za-z]):', '/$1'
    $dockerPath = $dockerPath.ToLower()
    
    $dockerCmd = @(
        "run", "--rm",
        "--env", "JAVA_OPTS=-DmaxYamlCodePoints=9999999",
        "-v", "${ProjectRoot}:/local",
        "openapitools/openapi-generator-cli:v7.14.0",
        "generate",
        "--config", "/local/.openapi-generator/config.yaml",
        "--input-spec", "/local/api/openapi.yaml",
        "--output", "/local",
        "--inline-schema-options", "RESOLVE_INLINE_ENUMS=true",
        "--http-user-agent", "go-netbox/$NetboxMajorVersion"
    )
    
    Write-Host "Docker command: docker $($dockerCmd -join ' ')" -ForegroundColor Gray
    
    & docker @dockerCmd
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "OpenAPI Generator failed with exit code $LASTEXITCODE"
        exit 1
    }
    Write-Host "OpenAPI Generator completed successfully" -ForegroundColor Green
}
else {
    Write-Host "`nSkipping Docker-based code generation (SkipDocker flag set)" -ForegroundColor Yellow
}

# Apply manual patches
# Note: Patch files have "//go:build ignore" on line 1 to exclude them from compilation.
# This line must be stripped when copying to the project root.
if (-not $SkipPatches) {
    Write-Host "`nApplying manual patches..." -ForegroundColor Yellow
    $patchFiles = Get-ChildItem "$ProjectRoot\patches" -Filter "*.go" -ErrorAction SilentlyContinue
    if ($patchFiles) {
        foreach ($patch in $patchFiles) {
            $destPath = "$ProjectRoot\$($patch.Name)"
            # Read content, skip the //go:build ignore line, and write to destination
            $content = Get-Content $patch.FullName -Raw
            # Remove the //go:build ignore line (with optional trailing newline)
            $content = $content -replace '^//go:build ignore\r?\n', ''
            Set-Content -Path $destPath -Value $content -NoNewline
            Write-Host "Applied patch: $($patch.Name)" -ForegroundColor Green
        }
    }
    else {
        Write-Host "No patches to apply" -ForegroundColor Gray
    }
}
else {
    Write-Host "`nSkipping patches (SkipPatches flag set)" -ForegroundColor Yellow
}

# Run go mod tidy
Write-Host "`nRunning go mod tidy..." -ForegroundColor Yellow
Push-Location $ProjectRoot
try {
    go mod tidy
    if ($LASTEXITCODE -ne 0) {
        Write-Error "go mod tidy failed with exit code $LASTEXITCODE"
        exit 1
    }
    Write-Host "go mod tidy completed" -ForegroundColor Green
}
finally {
    Pop-Location
}

# Run go fmt (goimports may not be available on Windows, so we use go fmt)
Write-Host "`nRunning go fmt..." -ForegroundColor Yellow
Push-Location $ProjectRoot
try {
    go fmt ./...
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "go fmt had issues (non-fatal)"
    }
    else {
        Write-Host "go fmt completed" -ForegroundColor Green
    }
}
finally {
    Pop-Location
}

# Try goimports if available
$goimports = Get-Command goimports -ErrorAction SilentlyContinue
if ($goimports) {
    Write-Host "`nRunning goimports..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    try {
        Get-ChildItem -Path . -Filter "*.go" -Recurse | ForEach-Object {
            goimports -w $_.FullName
        }
        Write-Host "goimports completed" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "`ngoimports not found, skipping (install with: go install golang.org/x/tools/cmd/goimports@latest)" -ForegroundColor Yellow
}

# Verify the build
Write-Host "`nVerifying build..." -ForegroundColor Yellow
Push-Location $ProjectRoot
try {
    go build .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "go build failed with exit code $LASTEXITCODE"
        exit 1
    }
    Write-Host "Build verified successfully!" -ForegroundColor Green
}
finally {
    Pop-Location
}

# Run tests if requested
if ($RunTests) {
    Write-Host "`nRunning unit tests..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    try {
        go test ./... -v
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Tests failed with exit code $LASTEXITCODE"
            exit 1
        }
        Write-Host "Unit tests passed!" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}

# Run integration tests if requested
if ($RunIntegrationTests) {
    Write-Host "`nRunning integration tests..." -ForegroundColor Yellow
    
    # Check for required environment variables
    if (-not $env:NETBOX_URL) {
        $env:NETBOX_URL = "http://localhost:8000"
        Write-Host "NETBOX_URL not set, using default: $env:NETBOX_URL" -ForegroundColor Yellow
    }
    if (-not $env:NETBOX_API_TOKEN) {
        Write-Warning "NETBOX_API_TOKEN not set. Integration tests may fail without authentication."
    }
    
    Push-Location $ProjectRoot
    try {
        go test -v ./test -tags=integration
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Integration tests failed with exit code $LASTEXITCODE"
            exit 1
        }
        Write-Host "Integration tests passed!" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "go-netbox generation completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
