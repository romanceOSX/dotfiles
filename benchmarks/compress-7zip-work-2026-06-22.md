# 7-Zip Compression Benchmark — work — 2026-06-22

Host: **WDXCND22144P90** (`work`)

Tool: [Phoronix Test Suite](https://www.phoronix-test-suite.com/) `pts/compress-7zip-1.13.0`  
Metric: MIPS (higher = better)

## Results Summary

| Node       | CPU                                   | Cores  | RAM   | OS                          | Compression (MIPS) | Decompression (MIPS) |
|------------|---------------------------------------|--------|-------|-----------------------------|--------------------|----------------------|
| **work**   | Intel Core i7-11850H @ 2.50 GHz       | 8c/16t | 56 GB | Ubuntu 22.04.5 LTS (WSL2)   | **44 856**         | **28 752**           |

## Notes

`work` is an 11th-gen Intel Core i7-11850H laptop running Ubuntu 22.04.5 LTS
under WSL2 (Windows host, inside the Deere VPN). With 8 cores / 16 threads and
56 GB RAM it posts steady, low-deviation numbers: 44 856 MIPS compression and
28 752 MIPS decompression.

On compression it lands in the middle of the fleet — 1.21× faster than `alien`
but 1.20× behind `remote-left` (Xeon Silver 4214) and behind `osx` (Apple M3).
On decompression it is effectively tied with `alien` (28 752 vs 28 969 MIPS) and
trails `osx` and `remote-left`. Running under WSL2 adds a thin virtualization
layer, so bare-metal results would likely be marginally higher.

---

## Raw Data

### work — WDXCND22144P90 (Intel Core i7-11850H)

```
Processor:  Intel Core i7-11850H @ 2.50 GHz, 8 cores / 16 threads
            Extensions: SSE 4.2 + AVX2 + AVX512 (F/DQ/CD/BW/VL/IFMA/VBMI/VBMI2/VNNI/BITALG/VPOPCNTDQ) + AES + SHA + RDRAND + RDSEED
            L3 Cache: 24 MB
Memory:     56 GB
Disk:       1 TB /dev/sdd — ext4
OS:         Ubuntu 22.04.5 LTS (WSL2), kernel 6.6.114.1-microsoft-standard-WSL2 (x86_64)
Compiler:   GCC 11.4.0 + Clang 21.1.8

7-Zip Compression 26.01 — pts/compress-7zip-1.13.0
Samples: 15

Compression Rating (MIPS):
  Runs:    46391 41935 43204 45205 43794 43801 45460 46136 46299 46441 43376 45078 43049 45951 46726
  Average: 44 856 MIPS   Deviation: 3.41%

Decompression Rating (MIPS):
  Runs:    29933 27266 26515 29202 28331 28506 29588 29539 29210 29008 28099 29450 29392 28193 29044
  Average: 28 752 MIPS   Deviation: 3.27%
```
