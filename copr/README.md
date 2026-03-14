# COPR packaging workspace

This directory keeps downstream patch stacks for packages built in
`samcday/rokkitpokkit`.

## Packit-primary flow

- Packit config lives at `packit.yaml` in the repository root.
- Current package paths are `copr/anaconda` and `copr/anaconda-webui`.
- Packit COPR builds run on pull requests and on commits to `main`.
- Build targets are:
  - `fedora-rawhide-aarch64`, `fedora-rawhide-x86_64`
  - `fedora-44-aarch64`, `fedora-44-x86_64`
  - `fedora-43-aarch64`, `fedora-43-x86_64`
  - `fedora-42-aarch64`, `fedora-42-x86_64`

## Manual fallback flow

If Packit is unavailable or you want a one-off build, use the local SRPM helper
from `~/src/pocketblue/packages/.copr/Makefile` and submit directly with
`copr-cli`.
