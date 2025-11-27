$pubCacheRoot = "L:\.pub-cache\hosted\pub.dev"
$pluginName = "ffmpeg_kit_flutter_min_gpl-5.1.0"
$buildGradlePath = "${pubCacheRoot}\${pluginName}\android\build.gradle"

if (-Not (Test-Path $buildGradlePath)) {
    Write-Error "Unable to find build.gradle at: $buildGradlePath"
    exit 1
}

Write-Host "Fixing literal \n sequences in build.gradle at $buildGradlePath"
$content = Get-Content -Raw $buildGradlePath

# Replace the literal '\n' sequence with real newline where we added the namespace
$content = $content -replace "\\n", "`n"
Set-Content -Path $buildGradlePath -Value $content -Force
Write-Host "Fixed file."
