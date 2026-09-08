# Test protocol (per PoC, per session)

Why the dance: these PoCs are session-interactive LPEs (ctfmon session cache,
input desktop, per-user hives, TieringEngine). They must run in an INTERACTIVE
logon session of a standard user. Admin one-shots (wmiexec/schtasks) validate
AV verdicts, but the LPE itself needs a real session.

1.  Verify box up: `nc -zv HOST 445 5985` (and 3389 for RDP).
2.  `./nm.sh build HOST USER PASS` : record `ver` + DisplayVersion into VERDICT.md.
3.  `./nm.sh mpstatus HOST USER PASS` : record Defender/cloud status.
4.  `./nm.sh user HOST USER PASS nmtest <pass>` : throwaway standard user.
5.  Push binaries: `./nm.sh push` (lands on C:\ProgramData).
6.  Run PoC in an interactive nmtest session (RDP in as nmtest if 3389 is
    open, via xfreerdp from Kali), one named tmux window per action.
7.  Verdict x2: immediately after run, and again +10 min
    (`./nm.sh threats HOST USER PASS`) because cloud verdicts flip late.
8.  LPE result: SYSTEM shell or not; race PoCs: record run counts.
9.  Capture evidence to the poc/ discipline, write VERDICT.md, commit.
10. Different Windows build = re-test, never assume.

## VERDICT.md template

    # VERDICT: <poc name>
    - date: 2026-09-08
    - build tested: (ver output / DisplayVersion)
    - binary: bin/nm_*_r1.exe sha256 <hash prefix>
    - defender status: (rt/cloud on?)
    - verdict 0min: UNDETECTED / DETECTED:<threat name>
    - verdict +10min: UNDETECTED / DETECTED:<threat name>
    - lpe result: SYSTEM / no / partial
    - runs: <n> (race PoCs)
    - notes: <freeform>
