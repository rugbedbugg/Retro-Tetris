# TUI Tetris (x86-64 assembly)

A Tetris game for the Windows console, written in NASM x86-64 assembly. It renders
with ANSI escape codes on a monochrome green palette and reads keyboard input through
the Win32 console API. No C runtime is linked.

## Requirements

- **NASM** — assembler (`nasm`).
- **lld-link** — linker (ships with LLVM, at `C:\Program Files\LLVM\bin`).
- **Windows SDK** — provides `kernel32.Lib` (default path
  `C:\Program Files (x86)\Windows Kits\10\Lib\<version>\um\x64`).

## Build

```powershell
.\build.ps1
```

This assembles `tetris.asm` to a COFF object and links it into `tetris.exe`.

## Run

```powershell
.\tetris.exe
```

## Controls

| Key            | Action     |
| -------------- | ---------- |
| `7` / Left     | Move left  |
| `9` / Right    | Move right |
| `8` / Up       | Rotate     |
| `4` / Down     | Soft drop  |
| `Space`        | Hard drop  |
| `Q` / `Esc`    | Quit       |
