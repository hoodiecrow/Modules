source -encoding utf-8 [file join [file dirname [info nameofexecutable]] tkcon.tcl]

namespace eval ::tkcon {
    variable PRIV
    variable OPT
    set PRIV(root) .console
    set PRIV(showOnStartup) 0
    set PRIV(protocol) exit
    #set PRIV(protocol) {tkcon hide}
    set OPT(exec) ""
}

catch {wm iconify .}
