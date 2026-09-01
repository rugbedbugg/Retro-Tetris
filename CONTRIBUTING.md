# Contributing to Retro Tetris

Retro Tetris is a Windows x86-64 NASM project. Contributions should preserve the native console implementation and the existing keyboard controls.

## Development setup

Use Windows with NASM and LLVM's `lld-link` available on `PATH`. Build from PowerShell:

```powershell
.\build.ps1
```

Run `tetris.exe` from a Windows terminal that supports the console APIs used by the game.

## Verification

The project uses manual game checks. After every gameplay or rendering change, verify that:

- the board and next-piece display render correctly;
- movement, rotation, soft drop, hard drop, pause, and quit respond;
- completed lines clear and scoring advances;
- a fresh game and a game-over restart work without corrupting state.

## Pull requests

- Describe the Windows and assembler versions used for testing.
- Keep platform/API changes separate from gameplay changes when possible.
- Comment non-obvious register ownership, stack use, and Win32 calling-convention assumptions.
- Do not commit generated executables, object files, or packaging artifacts.
