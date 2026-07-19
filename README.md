# Retro Tetris

**Tetris for the terminal, hand-written in x86-64 assembly.**

A Windows console Tetris on a green-phosphor palette: ANSI escape codes for the
screen, the Win32 console API for input, and not a line of C. Just NASM.

## Controls

| Key | Action |
| --- | --- |
| `←` `→` / `7` `9` | Move |
| `↑` / `8` | Rotate |
| `↓` / `4` | Soft drop |
| `Space` | Hard drop |
| `P` | Pause |
| `Q` / `Esc` | Quit |

## Build & run

```powershell
.\build.ps1     # nasm + lld-link -> tetris.exe
.\tetris.exe
```

Needs NASM, LLVM's `lld-link`, and the Windows SDK. Scores are saved to
`scores.txt` — the top ten sit beside the board and on the game-over screen.
