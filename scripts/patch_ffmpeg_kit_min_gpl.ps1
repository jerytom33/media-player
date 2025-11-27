# This script patches the ffmpeg_kit_flutter_min_gpl plugin build.gradle in the local pub cache
# It adds a namespace declaration to the Android library build.gradle if missing.
# Usage: Run in PowerShell: `.	ools\patch_ffmpeg_kit_min_gpl.ps1` (requires permission)

$pubCacheRoot = "L:\.pub-cache\hosted\pub.dev"
$pluginName = "ffmpeg_kit_flutter_min_gpl-5.1.0"
$buildGradlePath = "${pubCacheRoot}\${pluginName}\android\build.gradle"

if (-Not (Test-Path $buildGradlePath)) {
    Write-Error "Unable to find build.gradle at: $buildGradlePath"
    exit 1
}

Write-Host "Patching plugin build.gradle at $buildGradlePath"
$content = Get-Content -Raw $buildGradlePath

# Check if 'namespace' is present
if ($content -match "namespace\s*=") {
    Write-Host "Namespace already present in build.gradle. Nothing to do."
    exit 0
}

# Try to insert namespace declaration inside android { } block
$pattern = 'android\s*\{'
if ($content -match $pattern) {
    # Insert namespace after 'android {' line
    $newContent = $content -replace 'android\s*\{', 'android {\n    namespace "com.arthenica.ffmpeg_kit_min_gpl"'
    Set-Content -Path $buildGradlePath -Value $newContent -Force
    Write-Host "Added namespace to build.gradle"
    exit 0
} else {
    Write-Error "Could not find android { ... } block in build.gradle. Please inspect the plugin build.gradle manually."
    exit 1
}
