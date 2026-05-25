$content = Get-Content "C:\spelling-game\BUILD.BAT" -Raw

# Show lines 195-204 (0-indexed: 194-203) with their hex
$lines = $content -split "`r`n"
for ($i = 194; $i -le 204; $i++) {
    $hex = [BitConverter]::ToString([Text.Encoding]::ASCII.GetBytes($lines[$i]))
    Write-Host "$i : $hex"
}
