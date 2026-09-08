# nightmare: reworked Windows LPE arsenal for CTF

Reworked (recompiled, hash-changed) Windows LPE PoCs from
[Nightmare_Eclipse](https://git.churchofmalware.org/Nightmare_Eclipse), for
authorized CTF/lab privilege escalation. Upstream clones live read-only in the
ZTorch vault at `raw/git/`; this repo holds only reworked source, compiled
binaries, and Defender verdicts.

Original author attribution preserved. All builds by Encod3d-Sec.

## Triage table

| PoC | Bug | Language | Builds affected | Chain status | Defender verdict |
|---|---|---|---|---|---|
| mini-plasma | CVE-2020-17103 cldflt placeholder hydration (claimed unpatched, all builds) | C# (net48) | all per author | turnkey SYSTEM shell, race condition | PENDING |
| green-plasma | ctfmon BaseNamedObjects session-cache section creation | C++ | Win11/2022/2026 (author unsure re Win10) | stripped upstream; creates privileged section, chain to SYSTEM = Phase 2 | PENDING |
| red-sun | Defender cloud-tag rewrite-to-origin file overwrite | C++ | Defender cloud protection ON | turnkey (overwrites System32\TieringEngineService.exe then self-launches) | PENDING |
| legacy-hive | User Profile Service arbitrary hive load | C++ | all supported at July 2026 patches per author | stripped; needs creds of a 2nd standard user + a 3rd (admin) username | PENDING |
| blue-hammer | Defender RPC `MpUpdateEngineSignature` path abuse + offreg | C++ | Defender-managed hosts | built complete; author admits the PoC has bugs; treat as reference build until tested | PENDING |

## What "reworked" means here

- Cross-compiled with mingw-w64 (upstream used MSVC): different toolchain, PE
  layout, and hashes by construction. Binaries are static (no runtime DLL deps
  except the C# trio), stripped, renamed (nm_*_r1.exe naming).
- No logic changes. Every functional delta vs upstream is a portability fix,
  listed in [BUILD.md](BUILD.md).
- MiniPlasma: built from source on Linux (dotnet SDK, net48). Dependencies
  (NtApiDotNet.dll, Microsoft.Win32.TaskScheduler.dll) ship loose instead of
  Costura-woven (upstream wove them in); push all three files together.

## Build

Per-PoC recipes: [BUILD.md](BUILD.md). Reproduce with mingw-w64 + dotnet SDK 8.

## Verdicts

Per-PoC [VERDICT.md](mini-plasma/VERDICT.md) files record: Windows build
tested, date, Defender verdict at 0 and +10 minutes (cloud verdicts flip
late), LPE result, run counts for race PoCs. Verdicts are per-build: a
different target build = re-test, never assume.

## Limits

- Race-condition PoC (mini-plasma): variable success, record run counts.
- green-plasma and legacy-hive are intentionally stripped upstream; the full
  chains are Phase 2 exploit-dev work.
- blue-hammer upstream compiled only after stripping file-scope `static` from
  the MIDL-generated client stubs (MSVC tolerates the pattern, GCC does not).
  All RPC stubs including `Proc42_ServerMpUpdateEngineSignature` are present;
  the author's README still admits the PoC has bugs, so verify on-target before
  relying on it.

## License / attribution

Upstream LICENSE files preserved in raw/git; Nightmare_Eclipse is the original
author of the underlying PoCs. This repo only adds portability fixes,
build recipes, and verdict data.
