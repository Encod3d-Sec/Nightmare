#!/usr/bin/env bash
# nm.sh: admin one-shots against a Windows test box (run from Kali).
# One subcommand per action; pair each call with a named tmux window.
# Usage: nm.sh <cmd> <host> <admin-user> <admin-pass> [args...]
set -euo pipefail
cmd=$1 host=$2 user=$3 pass=$4; shift 4

run_cmd() {
  impacket-wmiexec "${user}:${pass}@${host}" "$1"
}

case "$cmd" in
  push)   # push files via SMB into C:\ProgramData
    local=$1; shift
    impacket-smbclient "${user}:${pass}@${host}" -c "use C$; put ${local};"
    ;;
  user)   # create throwaway standard user: nm.sh user HOST U P newuser newpass
    impacket-wmiexec "${user}:${pass}@${host}" 'cmd /c net user '"$1 $2"' /add && net user '"$1"' /active:yes'
    ;;
  build)  # record Windows build
    run_cmd 'cmd /c ver & reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v DisplayVersion'
    ;;
  mpstatus) # Defender engine + cloud status
    run_cmd 'powershell -c "Get-MpComputerStatus | Select-Object AMServiceEnabled,AntispywareEnabled,RealTimeProtectionEnabled,BehaviorMonitorEnabled,IoavProtectionEnabled,NISEnabled, AntivirusSignatureLastUpdated,QuickScanEndTime"'
    ;;
  threats)  # recent Defender detections
    run_cmd 'powershell -c "Get-MpThreatDetection | Sort-Object InitialDetectionTime -Descending | Select-Object -First 10 InitialDetectionTime,ProcessName,Resources | Format-List"'
    ;;
  pull)   # fetch a file back
    impacket-smbclient "${user}:${pass}@${host}" -c "use C$; get $1;"
    ;;
  *) echo "cmds: push|user|build|mpstatus|threats|pull"; exit 1 ;;
esac
