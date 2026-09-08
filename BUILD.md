# BUILD.md

Exact recipes for the r1 builds. Toolchain: mingw-w64 15 (Kali Linux), dotnet
SDK 8.0 (Linux). Every delta vs upstream is a portability fix; no exploit
logic changed.

## Sysroot prep (all C++ builds)

    # cfapi.h: Windows SDK header (mingw-w64 does not ship cfapi.h)
    curl -sL -o sysroot/cfapi.h \
      https://raw.githubusercontent.com/tpn/winsdk-10/master/Include/10.0.16299.0/um/cfapi.h

    # cldapi import library (mingw-w64 does not ship libcldapi.a)
    printf 'LIBRARY cldapi.dll\nEXPORTS\nCfRegisterSyncRoot\nCfConnectSyncRoot\nCfCreatePlaceholders\nCfGetPlatformInfo\nCfAbortOperation\nCfDisconnectSyncRoot\nCfExecute\nCfUnregisterSyncRoot\n' > sysroot/cldapi.def
    x86_64-w64-mingw32-dlltool -m i386:x86-64 --as-flags=--64 -d sysroot/cldapi.def -l sysroot/lib/libcldapi.a

    # case shims: the sources include <Windows.h>, <AclAPI.h>, <UserEnv.h>,
    # <Lmcons.h>, <Shlwapi.h>, <WinInet.h>, <KtmW32.h>, <NtSecApi.h>, <Sddl.h>;
    # mingw ships lowercase names and the Linux fs is case-sensitive
    for h in Windows AclAPI UserEnv Lmcons Shlwapi WinInet KtmW32 NtSecApi Sddl; do
      printf '#pragma once\n#include <%s.h>\n' "$(echo $h | tr 'A-Z' 'a-z')" > sysroot/$h.h
    done

cfapi.h compat patch (post-16299 SDK additions), inserted after
`#include <winapifamily.h>`:

    #ifndef _CORRELATION_VECTOR_DEFINED
    typedef struct _CORRELATION_VECTOR { CHAR Version; CHAR Identifier[64]; } CORRELATION_VECTOR, *PCORRELATION_VECTOR;
    #define _CORRELATION_VECTOR_DEFINED
    #endif
    #ifndef CF_PLACEHOLDER_MANAGEMENT_POLICY_DEFAULT
    #define CF_PLACEHOLDER_MANAGEMENT_POLICY_DEFAULT 0
    typedef int CF_PLACEHOLDER_MANAGEMENT_POLICY;
    #endif
    #ifndef _CF_REQUEST_KEY_DEFINED
    typedef struct CF_REQUEST_KEY { ULONG LowPart; LONG HighPart; } CF_REQUEST_KEY, *PCF_REQUEST_KEY;
    #define _CF_REQUEST_KEY_DEFINED
    #endif

Then append `CF_PLACEHOLDER_MANAGEMENT_POLICY PlaceholderManagement;` to
`CF_SYNC_POLICIES`, and `CF_REQUEST_KEY RequestKey;` to both `CF_CALLBACK_INFO`
and `CF_OPERATION_INFO`.

## green-plasma (GreenPlasma.cpp, unmodified copy)

    x86_64-w64-mingw32-g++ -O2 -municode -static -static-libgcc -static-libstdc++ -s \
      -isystem sysroot -o nm_gp_r1.exe GreenPlasma.cpp \
      -lntdll -luser32 -ladvapi32 -lshell32 -lole32

## red-sun (RedSun.cpp)

Source delta: the local `FILE_RENAME_INFORMATION` typedef (lines 23-35
upstream) is removed; mingw's own definition is used instead (the code only
touches the BOOLEAN-first members, which are layout-compatible).

    x86_64-w64-mingw32-g++ -O2 -DUNICODE -D_UNICODE -D_WIN32_WINNT=0x0A00 -DNTDDI_VERSION=0x0A000004 \
      -static -static-libgcc -static-libstdc++ -s -isystem sysroot \
      -o nm_rs_r1.exe RedSun.cpp sysroot/lib/libcldapi.a \
      -lntdll -lsynchronization -lole32 -loleaut32 -luuid -luser32

## legacy-hive (LegacyHive.cpp, unmodified copy)

    x86_64-w64-mingw32-g++ -O2 -municode -D_declspec=__declspec -static -static-libgcc -static-libstdc++ -s \
      -isystem sysroot -isystem <blue-hammer-dir> \
      -o nm_lh_r1.exe LegacyHive.cpp <blue-hammer-dir>/offreg.lib \
      -lntdll -ladvapi32 -luserenv -lrpcrt4 -luser32

`offreg.lib` is the MSVC-format import library shipped in the upstream
BlueHammer repo; GNU ld links MSVC short-import libraries directly.

## blue-hammer (FunnyApp.cpp + MIDL windefend_c.c)

Source deltas (applied to the src/ copies):
1. FunnyApp.cpp: `#define min(a,b) (((a)<(b))?(a):(b))` inserted after the
   pragma block; mingw headers undefine the min macro in C++ mode, so a
   -D flag cannot survive windows.h.
2. windefend_c.c: strip column-0 `static` from the 716 file-scope definitions
   (MSVC tolerates static-after-nonstatic, GCC errors). Function-local
   statics are indented and untouched.

    x86_64-w64-mingw32-g++ -O2 -DUNICODE -D_UNICODE -D_declspec=__declspec \
      -D_WIN32_WINNT=0x0A00 -static -static-libgcc -static-libstdc++ \
      -isystem sysroot -c FunnyApp.cpp -o FunnyApp.o
    x86_64-w64-mingw32-gcc -O2 -DUNICODE -D_UNICODE -D_declspec=__declspec \
      -D_M_AMD64=100 -c windefend_c.c -o windefend_c.o
    # _M_AMD64 gates the entire MIDL file; mingw does not define it

    printf '#define INITGUID\n#include <windows.h>\n#include <wuapi.h>\n' > wuguid.c
    x86_64-w64-mingw32-gcc -c wuguid.c -o wuguid.o

    x86_64-w64-mingw32-g++ -municode -static -static-libgcc -static-libstdc++ -s \
      -o nm_bh_r1.exe FunnyApp.o windefend_c.o wuguid.o \
      <blue-hammer-dir>/offreg.lib sysroot/lib/libcldapi.a \
      -lntdll -lsynchronization -lwininet -lktmw32 -lshlwapi -lrpcrt4 -lcabinet \
      -ladvapi32 -lole32 -loleaut32 -luuid -luser32 -lshell32

## mini-plasma (Program.cs, unmodified; net48 rebuild)

    dotnet build -c Release   # uses nm_mp.csproj in src/, pins NtApiDotNet 1.1.33 + TaskScheduler 2.12.2

Costura.Fody (upstream wove deps into the exe) replaced by loose DLLs. Push
exe + NtApiDotNet.dll + Microsoft.Win32.TaskScheduler.dll together. Requires
.NET Framework 4.8 on target.

## Post-build

    sha256sum bin/*.exe   # record per-release hashes in VERDICT.md when tested
