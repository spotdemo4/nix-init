# nix init action

[![check status](https://img.shields.io/github/actions/workflow/status/spotdemo4/nix-init/check.yaml?logo=GitHub&logoColor=%23cdd6f4&label=check&labelColor=%2311111b)](https://github.com/spotdemo4/nix-init/actions/workflows/check.yaml)
[![vulnerable status](https://img.shields.io/github/actions/workflow/status/spotdemo4/nix-init/vulnerable.yaml?logo=nixos&logoColor=%2389dceb&label=vulnerable&labelColor=%2311111b)](https://github.com/spotdemo4/nix-init/actions/workflows/vulnerable.yaml)

composite action to initialize nix-based repos. Got tired of writing basically the same few steps for every job so this does all the important stuff in one:

- monitor network activity with harden-runner
- checkout the repository
- install nix
- setup caching
- (optional) use development shell environment
