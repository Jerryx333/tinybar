# Contributing

TinyBar is an experimental native prototype. Discuss a concrete failure mode or small improvement before adding broad features.

- Run `bash scripts/check.sh` and `bash scripts/verify.sh` on macOS. For layout changes, run `bash scripts/verify.sh --integration` in a logged-in desktop with other managers stopped, then `bash scripts/recovery.sh` to check quit/crash recovery. Both write ignored local reports.
- Distinguish real-device evidence from geometry tests and synthetic notification coverage. Do not claim display or OS support without observation.
- Keep the app event-driven; measurement tools and fixtures stay outside the shipped app. Check idle CPU and physical footprint with `bash scripts/benchmark.sh`.
- Do not collect private app inventories, screenshots or credentials. Do not silently replace another manager, alter its settings or enable startup.
- Preserve third-party attribution and prioritize recoverability, bounded work and low resource use.

Use Conventional Commit subjects. Keep generated binaries, local reports and environment notes outside Git. See [the guide](docs/guide.md) and [validation](docs/validation.md).
