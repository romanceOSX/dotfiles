# 7-Zip Compression Benchmark — 2026-06-21

Tool: [Phoronix Test Suite](https://www.phoronix-test-suite.com/) `pts/compress-7zip-1.13.0`  
Metric: MIPS (higher = better)

## Results Summary

| Node       | CPU                              | Cores | RAM   | OS                    | Compression (MIPS) | Decompression (MIPS) |
|------------|----------------------------------|-------|-------|-----------------------|--------------------|----------------------|
| **osx**    | Apple M3                         | 8     | 16 GB | macOS 26.5.1 (arm64)  | **56 359**         | **32 997**           |
| **alien**  | Intel Core i7-8750H @ 4.10 GHz   | 6c/12t| 16 GB | Ubuntu 26.04 (x86_64) | 37 208             | 28 969               |
| **pi**     | ARMv8 Cortex-A53 @ 1.20 GHz     | 4     | 906 MB| Debian 12 (aarch64)   | 2 222              | 4 485                |

## Verdict

**osx (Apple M3) is the clear winner** for heavy CPU processing — 1.5× faster than alien on
compression and 1.14× faster on decompression. However, it is a laptop with macOS power
management in the loop and cannot be used as a headless server node.

**alien is the recommended server for heavy processing.** It is the only always-on,
headless Linux machine in the tailscale mesh. With 6 cores / 12 threads, 16 GB RAM, and
two 1 TB disks it has both the throughput and the storage headroom for sustained workloads.

**pi is not suitable** for heavy processing — roughly 17× slower than alien on compression.
Best reserved for lightweight / IoT tasks.

---

## Raw Data

### osx — Apple MacBook Pro (Apple M3)

```
Processor:  Apple M3, 8 cores
Memory:     16 GB
Disk:       927 GB APFS
OS:         macOS 26.5.1, kernel 25.5.0 (arm64)
Compiler:   GCC 15.2.0 + Clang 21.0.0 + Xcode 26.5

7-Zip Compression 26.01 — pts/compress-7zip-1.13.0
Samples: 15

Compression Rating (MIPS):
  Runs:    39749 50718 46992 54285 55843 58124 60477 59324 62874 57837 59705 61831 60487 58174 58960
  Average: 56 359 MIPS   Deviation: 11.04%
  Note: high deviation reflects macOS thermal ramp-up from a cold start; steady-state ~59–62 k MIPS.

Decompression Rating (MIPS):
  Runs:    24024 31093 28993 32115 34552 34659 34740 34856 34790 34392 34798 34769 33806 32999 34373
  Average: 32 997 MIPS   Deviation: 9.12%
```

### alien — Alienware 15 R4 (Intel Core i7-8750H)

```
Processor:  Intel Core i7-8750H @ 4.10 GHz, 6 cores / 12 threads
            Extensions: SSE 4.2 + AVX2 + AVX + RDRAND + FSGSBASE
            L3 Cache: 9 MB   Microcode: 0xfa
GPU:        NVIDIA GeForce GTX 1060 Mobile (nouveau driver)
Memory:     16 GB
Disk:       1 TB KINGSTON SA2000M8 (NVMe) + 1 TB Seagate ST1000LX015 — ext4
OS:         Ubuntu 26.04, kernel 7.0.0-22-generic (x86_64)
Compiler:   GCC 15.2.0 + Clang 21.1.8

7-Zip Compression 26.01 — pts/compress-7zip-1.13.0
Samples: 15

Compression Rating (MIPS):
  Runs:    40873 38193 38420 37320 36454 36731 36866 36744 36408 36522 36803 36807 36661 36340 36980
  Average: 37 208 MIPS   Deviation: 3.18%

Decompression Rating (MIPS):
  Runs:    33200 29760 30638 28919 28483 28020 28639 28233 28329 28236 28956 28271 28149 28225 28472
  Average: 28 969 MIPS   Deviation: 4.71%
```

### pi — Raspberry Pi 3 Model B Rev 1.2 (ARMv8 Cortex-A53)

```
Processor:  ARMv8 Cortex-A53 @ 1.20 GHz, 4 cores  (governor: ondemand)
Memory:     906 MB
Disk:       128 GB USD (SD card) — ext4, noatime
OS:         Debian 12, kernel 6.12.34+rpt-rpi-v8 (aarch64)
Compiler:   GCC 15.2.0 + Clang 21.1.8
Note:       CPU governor was NOT set to performance — results may be slightly conservative.

7-Zip Compression 26.01 — pts/compress-7zip-1.13.0
Samples: 3

Compression Rating (MIPS):
  Runs:    2228 2197 2242
  Average: 2 222 MIPS   Deviation: 1.04%

Decompression Rating (MIPS):
  Runs:    4421 4559 4476
  Average: 4 485 MIPS   Deviation: 1.55%
```
