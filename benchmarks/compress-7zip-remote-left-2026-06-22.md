# 7-Zip Compression Benchmark — remote-left — 2026-06-22

Host: **WDXMXL1213CC8** (`remote-left`)

Tool: [Phoronix Test Suite](https://www.phoronix-test-suite.com/) `pts/compress-7zip-1.13.0`  
Metric: MIPS (higher = better)

## Results Summary

| Node            | CPU                                   | Cores  | RAM   | OS                          | Compression (MIPS) | Decompression (MIPS) |
|-----------------|---------------------------------------|--------|-------|-----------------------------|--------------------|----------------------|
| **remote-left** | Intel Xeon Silver 4214 @ 2.20 GHz     | 12c/24t| 31 GB | Ubuntu 26.04 LTS (WSL2)     | **53 814**         | **36 357**           |

## Notes

`remote-left` is an Intel Xeon Silver 4214 workstation running Ubuntu 26.04 under
WSL2 (Windows host). With 12 cores / 24 threads and 31 GB RAM it posts strong,
low-deviation numbers: 53 814 MIPS compression and 36 357 MIPS decompression.
That places it ahead of `alien` on both metrics (1.45× compression, 1.26×
decompression) and behind only `osx` (Apple M3) on compression, while leading
`osx` on decompression. Running under WSL2 adds a thin virtualization layer, so
bare-metal results would likely be marginally higher.

---

## Raw Data

### remote-left — WDXMXL1213CC8 (Intel Xeon Silver 4214)

```
Processor:  Intel Xeon Silver 4214 @ 2.20 GHz, 12 cores / 24 threads
            Extensions: SSE 4.2 + AVX2 + AVX512 (F/DQ/CD/BW/VL/VNNI) + AES + RDRAND + RDSEED
Memory:     31 GB
Disk:       1 TB /dev/sdd — ext4
OS:         Ubuntu 26.04 LTS (WSL2), kernel 6.6.114.1-microsoft-standard-WSL2 (x86_64)
Compiler:   Clang 21.1.8

7-Zip Compression — pts/compress-7zip-1.13.0
Samples: 15

Compression Rating (MIPS):
  Runs:    44895 49525 54638 54103 55706 55522 53440 55952 54237 55656 56438 52990 54513 55136 54465
  Average: 53 814 MIPS   Deviation: 5.52%

Decompression Rating (MIPS):
  Runs:    30481 33680 36225 36900 36823 37652 36367 36910 36862 36978 37647 36607 38089 37460 36673
  Average: 36 357 MIPS   Deviation: 5.24%
```
