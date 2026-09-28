# PostToolUse hook: format Lua files Claude edits with stylua + the repo's stylua.toml.
# Fails open: always exits 0. Silent on success; one stderr line on a stylua error.
$ErrorActionPreference = 'Stop'
try {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path.TrimEnd('\')
    $file = ([Console]::In.ReadToEnd() | ConvertFrom-Json).tool_input.file_path
    if (-not $file -or $file -notmatch '\.lua$') { exit 0 }

    $full = [IO.Path]::GetFullPath($file)
    if (-not $full.StartsWith("$root\", [StringComparison]::OrdinalIgnoreCase)) { exit 0 }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { exit 0 }

    $stylua = (Get-Command stylua -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if (-not $stylua) {
        $mason = Join-Path $env:LOCALAPPDATA 'nvim-data\mason\packages\stylua\stylua.exe'
        if (Test-Path -LiteralPath $mason) { $stylua = $mason } else { exit 0 }
    }

    $err = & $stylua --config-path "$root\stylua.toml" $full 2>&1
    if ($LASTEXITCODE -ne 0) {
        $line = ($err | Select-Object -First 1) -replace '\s+', ' '
        [Console]::Error.WriteLine("stylua: $(Split-Path $full -Leaf): $line")
    }
} catch { }
exit 0
