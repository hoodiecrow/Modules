proc newcmd {} {
    global commands
    if {![info exists commands]} {
        set commands [dict create]
        return 0
    } else {
        return [dict size $commands]
    }
}

proc add {str args} {
    log::log d [info level 0]
    global acc cmd
    append acc($cmd) $str
    uplevel 1 $args
}

proc space {str args} {
    log::log d [info level 0]
    global acc cmd commands
    dict lappend commands $cmd $acc($cmd)
    set acc($cmd) $str
    uplevel 1 $args
}

proc push c {
    log::log d [info level 0]
    global acc cmd stack commands
    lappend stack $cmd
    set cmd [newcmd]
    dict set commands $cmd $c
    set acc($cmd) {}
}

proc pop {} {
    log::log d [info level 0]
    global acc cmd stack commands
    dict lappend commands $cmd $acc($cmd)
    set c $cmd
    set cmd [lindex $stack end]
    set stack [lrange $stack 0 end-1]
    append acc($cmd) ($c)
}

proc command {} {
    log::log d [info level 0]
    global acc cmd commands
    if {[info exists cmd]} {
        dict lappend commands $cmd $acc($cmd)
    }
    set cmd [newcmd]
    dict set commands $cmd S
    set acc($cmd) {}
}

proc success args {}
