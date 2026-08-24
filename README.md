# Retro Tetris

![GitHub last commit](https://img.shields.io/github/last-commit/rugbedbugg/Retro-Tetris?style=for-the-badge&labelColor=000000)
![GitHub repo size](https://img.shields.io/github/repo-size/rugbedbugg/Retro-Tetris?style=for-the-badge&labelColor=000000)
![Stars](https://img.shields.io/github/stars/rugbedbugg/Retro-Tetris?style=for-the-badge&labelColor=000000)
![Winget version](https://img.shields.io/badge/winget-rugbedbugg.RetroTetris-blue?style=for-the-badge&labelColor=000000)
![Chocolatey version](https://img.shields.io/chocolatey/v/retro-tetris?style=for-the-badge&labelColor=000000)

**Tetris for the terminal, hand-written in x86-64 assembly.** A Windows console Tetris on a green-phosphor palette: ANSI escape codes for the screen, the Win32 console API for input, and not a line of C. Just NASM.

## Status

**Active**

## Features

| Feature | Description |
|---------|-------------|
| Pure assembly | x86-64 NASM, zero C/C++/Rust |
| CRT aesthetic | Green-phosphor palette via ANSI escape codes |
| Raw input | Win32 Console API (arrow keys + numpad) |
| Classic mechanics | 7-bag randomizer, wall kicks, lock delay |
| Controls | Hard/soft drop, hold piece, next piece preview |
| High scores | Top 10 persisted to `scores.txt` |
| Pause/quit | `P` to pause, `Q`/`Esc` to quit |

## Tech Stack

| Component | Tool | Purpose |
|-----------|------|---------|
| Assembler | NASM | x86-64 assembly |
| Linker | LLVM lld-link | No MSVC `link.exe` required |
| System libs | Windows SDK | `kernel32.lib`, `user32.lib` |
| Build | PowerShell | `build.ps1` script |

## Architecture

### Rendering (ANSI + Win32 Console)

1. Virtual 20×10 board + side panels rendered to off-screen buffer
2. ANSI escape sequences: cursor positioning, color (green phosphor palette), clear
3. `WriteConsoleOutput` blits full frame each tick - no flicker, no partial redraws

### Input (Win32 Console API)

1. `ReadConsoleInput` reads `KEY_EVENT` records
2. Maps arrow keys, numpad, space, `P`, `Q`, `Esc` to game actions
3. No buffering - immediate response, supports key repeat via OS

### Game Loop

1. Fixed timestep (~60 FPS via `Sleep`)
2. Input poll → piece update → collision check → line clear → score update → render
3. 7-bag randomizer ensures fair piece distribution
4. Wall kicks (SRS-lite) for rotation near walls/floor

## Install

| Platform | Command |
|----------|---------|
| Windows (Winget) | `winget install rugbedbugg.RetroTetris` |
| Windows (Chocolatey) | `choco install retro-tetris` |

## Controls

| Key | Action |
|-----|--------|
| `←` `→` / `7` `9` | Move left / right |
| `↑` / `8` | Rotate clockwise |
| `↓` / `4` | Soft drop |
| `Space` | Hard drop |
| `P` | Pause / resume |
| `Q` / `Esc` | Quit |

## Build & Run

### Prerequisites

| Requirement | Details |
|-------------|---------|
| NASM | `nasm` on PATH |
| LLVM lld-link | `lld-link.exe` on PATH |
| Windows SDK | For `kernel32.lib`, `user32.lib`, etc. |

### Build

```powershell
.\build.ps1     # nasm + lld-link -> tetris.exe
```

### Run

```powershell
.\tetris.exe
```

Scores are saved to `scores.txt` - the top ten sit beside the board and on the game-over screen.

## Project Structure

```
Retro-Tetris/
├── src/
│   ├── main.asm          # Entry point, game loop, Win32 console setup
│   ├── render.asm        # ANSI rendering, frame buffer, color palette
│   ├── input.asm         # Win32 Console input handling
│   ├── tetris.asm        # Core game logic: pieces, board, collision, scoring
│   ├── random.asm        # 7-bag randomizer
│   └── scores.asm        # High-score load/save (scores.txt)
├── build.ps1             # NASM + lld-link build script
├── tetris.exe            # Built binary (gitignored)
├── scores.txt            # High scores (gitignored)
└── README.md
```

## Testing

No automated test suite (assembly game). Manual verification:

```powershell
.\build.ps1
.\tetris.exe
# Verify: renders, input responds, pieces move/rotate/drop, lines clear, scores persist
```

## Notes

| Note | Details |
|------|---------|
| Platform | Windows only (Win32 Console API + ANSI) |
| Terminal | Requires ANSI support (Windows Terminal, ConEmu, cmd.exe on Win10+) |
| Palette | Green phosphor hardcoded - no config yet |
| Exit | `Task Manager` → End Task loses score; `Q`/`Esc` saves gracefully |

## Links

- **Repo:** https://github.com/rugbedbugg/Retro-Tetris
- **Winget:** `rugbedbugg.RetroTetris`
- **Chocolatey:** `retro-tetris`
- **Issues:** https://github.com/rugbedbugg/Retro-Tetris/issues
- **Releases:** https://github.com/rugbedbugg/Retro-Tetris/releases