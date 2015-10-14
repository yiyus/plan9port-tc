# plan9port-tc
Plan 9 from User Space extensions for tinycorelinx

    Usage: plan9-install.sh [ TARGET ]
    
    Create a plan9.tcz extension from $PLAN9, if available, or from the latest
    version in github. In the former case, create also a plan9-local.tcz
    extension that loads plan9.tcz when the original $PLAN9 is not found.
    If TARGET is specified, install there first, later create plan9-local.tcz
    and, if installing from github, plan9.tcz

See also: https://github.com/yiyus/tce-make/blob/master/plan9port.tcm
