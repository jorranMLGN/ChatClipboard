# Packages the plugin as dist/ChatClipboard.op with only the files Openplanet needs, plus the license.
# Use -Install to copy it into the Openplanet plugins folder as well.
param([switch]$Install)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$root = $PSScriptRoot
$dist = Join-Path $root 'dist'
$out = Join-Path $dist 'ChatClipboard.op'

New-Item -ItemType Directory -Force $dist | Out-Null
if (Test-Path $out) { Remove-Item $out }

$files = @(Get-Item (Join-Path $root 'info.toml'), (Join-Path $root 'LICENSE')) + @(Get-ChildItem (Join-Path $root 'src') -Recurse -File -Filter *.as)

# Built by hand instead of Compress-Archive, which writes backslashes into entry names on PowerShell 5.1
$zip = [IO.Compression.ZipFile]::Open($out, 'Create')
try {
    foreach ($file in $files) {
        $entry = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entry) | Out-Null
    }
} finally {
    $zip.Dispose()
}
Write-Host "Built $out ($($files.Count) files)"

if ($Install) {
    $plugins = Join-Path $env:USERPROFILE 'OpenplanetNext\Plugins'
    Copy-Item $out $plugins -Force
    Write-Host "Installed to $plugins"
}
