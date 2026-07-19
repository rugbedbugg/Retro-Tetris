$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
    packageName    = 'retro-tetris'
    fileFullPath   = Join-Path $toolsDir 'retro-tetris.exe'
    url64bit       = 'https://github.com/rugbedbugg/Retro-Tetris/releases/download/v1.0.0/retro-tetris.exe'
    checksum64     = '1F41B6AC0F383FBD9587437AD46BDD96993E2DFE8771919EAE3C9CA6B85CF0ED'
    checksumType64 = 'sha256'
}

# Downloads the binary into the package's tools folder; Chocolatey then
# auto-creates a `retro-tetris` shim for the .exe on the PATH.
Get-ChocolateyWebFile @packageArgs
