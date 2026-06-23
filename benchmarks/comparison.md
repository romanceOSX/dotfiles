# Benchmark Comparison — All Systems

Compact, machine-readable summary of the `pts/compress-7zip-1.13.0` benchmark
(MIPS, higher = better) across every node. Numbers are plain integers (no
separators) so this table can be parsed directly by scripts.

| node        | host           | cpu                            | cores | threads | ram_gb | arch    | os                      | compression_mips | decompression_mips | samples | date       |
|-------------|----------------|--------------------------------|-------|---------|--------|---------|-------------------------|------------------|--------------------|---------|------------|
| osx         | -              | Apple M3                       | 8     | 8       | 16     | arm64   | macOS 26.5.1            | 56359            | 32997              | 15      | 2026-06-21 |
| remote-left | WDXMXL1213CC8  | Intel Xeon Silver 4214 2.20GHz | 12    | 24      | 31     | x86_64  | Ubuntu 26.04 LTS (WSL2) | 53814            | 36357              | 15      | 2026-06-22 |
| alien       | -              | Intel Core i7-8750H 4.10GHz    | 6     | 12      | 16     | x86_64  | Ubuntu 26.04            | 37208            | 28969              | 15      | 2026-06-21 |
| pi          | -              | ARMv8 Cortex-A53 1.20GHz       | 4     | 4       | 1      | aarch64 | Debian 12               | 2222             | 4485               | 3       | 2026-06-21 |

## Rankings

- **Compression:** osx (56359) > remote-left (53814) > alien (37208) > pi (2222)
- **Decompression:** remote-left (36357) > osx (32997) > alien (28969) > pi (4485)

## Notes

- `osx` (Apple M3) leads compression but is a laptop with macOS power management
  and cannot serve as a headless node.
- `remote-left` (Xeon Silver 4214) is the decompression leader and the strongest
  always-available Linux node; runs under WSL2, so bare metal would be marginally
  higher.
- `alien` is a solid always-on headless server with two 1 TB disks.
- `pi` is ~17–24× slower; reserve for lightweight / IoT tasks.

Source data: see `compress-7zip-2026-06-21.md` and
`compress-7zip-remote-left-2026-06-22.md`.
