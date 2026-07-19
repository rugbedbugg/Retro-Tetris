# Assemble and link the console Tetris into tetris.exe.
$ErrorActionPreference = "Stop"

# Locate the x64 Windows SDK import libraries (kernel32.Lib lives here).
$sdkRoot = "C:\Program Files (x86)\Windows Kits\10\Lib"
$sdkLib  = Get-ChildItem $sdkRoot -Directory |
           Sort-Object Name -Descending |
           ForEach-Object { Join-Path $_.FullName "um\x64" } |
           Where-Object { Test-Path (Join-Path $_ "kernel32.Lib") } |
           Select-Object -First 1

if (-not $sdkLib) { throw "Could not find kernel32.Lib under $sdkRoot" }

# Resolve nasm: prefer PATH, fall back to the default install location.
$nasm = (Get-Command nasm -ErrorAction SilentlyContinue).Source
if (-not $nasm) { $nasm = "C:\Program Files\NASM\nasm.exe" }
if (-not (Test-Path $nasm)) { throw "Could not find nasm.exe" }

# Resolve llvm-rc (LLVM's resource compiler) for the icon + version resource.
$llvmrc = (Get-Command llvm-rc -ErrorAction SilentlyContinue).Source
if (-not $llvmrc) { $llvmrc = "C:\Program Files\LLVM\bin\llvm-rc.exe" }
if (-not (Test-Path $llvmrc)) { throw "Could not find llvm-rc.exe" }

& $nasm -f win64 tetris.asm -o tetris.obj
if ($LASTEXITCODE -ne 0) { throw "nasm failed" }

& $llvmrc /fo tetris.res tetris.rc
if ($LASTEXITCODE -ne 0) { throw "llvm-rc failed" }

lld-link tetris.obj tetris.res /subsystem:console /entry:main kernel32.lib "/libpath:$sdkLib" /out:tetris.exe
if ($LASTEXITCODE -ne 0) { throw "lld-link failed" }

Write-Host "Built tetris.exe"
