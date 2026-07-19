# Packaging

Manifests for distributing Retro Tetris through package managers. All of them
point at the `retro-tetris.exe` asset on the [GitHub release](https://github.com/rugbedbugg/Retro-Tetris/releases/tag/v1.0.0)
and pin its SHA256.

Scoop is already live from `bucket/retro-tetris.json` in the repo root and needs
no submission. The two below require your account and pass through a moderation
queue, so they are prepared here for you to submit.

## winget

Files: `winget/manifests/r/rugbedbugg/RetroTetris/1.0.0/` (three YAML files,
`portable` installer type, validated with `winget validate`).

To submit:

1. Fork [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs).
2. Copy the `winget/manifests/` tree into the fork's `manifests/` folder.
3. Open a PR. Automated validation runs first, then a moderator reviews.

Faster alternative with [wingetcreate](https://github.com/microsoft/winget-create):

    wingetcreate submit --token <gh-token> winget/manifests/r/rugbedbugg/RetroTetris/1.0.0

## Chocolatey

Files: `chocolatey/` (`retro-tetris.nuspec` + `tools/`). The install script
downloads the release binary and Chocolatey shims it as `retro-tetris`.

To submit (needs a free account + API key from https://community.chocolatey.org):

    cd chocolatey
    choco pack
    choco apikey --key <your-key> --source https://push.chocolatey.org/
    choco push retro-tetris.1.0.0.nupkg --source https://push.chocolatey.org/

It then enters the community moderation queue (automated checks + human review).

## Caveats

- **Unsigned binary.** Neither requires code signing, but users may see a
  SmartScreen "unknown publisher" prompt, and both moderation pipelines scan
  the binary. A signing certificate is the only fix.
- **Name.** The identifiers use `rugbedbugg.RetroTetris` / `retro-tetris`
  rather than anything reading as official "Tetris", which trademark review
  is more likely to flag.
- **New versions.** On each release, bump the `version` and `InstallerSha256`
  / `checksum64` to the new asset's hash, then resubmit.
