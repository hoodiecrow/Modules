
proc action {what args} {
    global word commands contexts cmdnum ctxnum cmddict ctxdict
    switch $what {
        init {
            set word {}
            set commands {}
            set cmdnum 0
            set cmddict {}
            set contexts {}
            set ctxnum 0
            set ctxdict {}
        }
        bctx {
            set args [lassign $args str]
            incr ctxnum
            dict set ctxdict $ctxnum [list $str]
            set contexts [linsert $contexts 0 $ctxnum]
            set args [action bcmd {*}$args]
        }
        ectx {
            set args [action ecmd {*}$args]
            set contexts [lassign $contexts idx]
            set word <$idx>
        }
        bcmd {
            incr cmdnum
            set commands [linsert $commands 0 $cmdnum]
            set args [action bwrd {*}$args]
        }
        ecmd {
            set args [action ewrd {*}$args]
            set commands [lassign $commands idx]
            dict lappend ctxdict [lindex $contexts 0] ($idx)
        }
        bwrd {
            set word {}
        }
        awrd {
            set args [lassign $args str]
            append word $str
        }
        ewrd {
            dict lappend cmddict [lindex $commands 0] $word
        }
        succ {
            set args [lassign $args str]
            set args [action ectx {*}$args]
        }
        default {
            ;
        }
    }
    return $args
}

proc init args {
    set args [action init {*}$args]
    uplevel 1 $args
}

proc enter args {
    set args [action bctx {*}$args]
    uplevel 1 $args
}

proc leave args {
    set args [action ectx {*}$args]
    uplevel 1 $args
}

proc add args {
    global word
    set args [action awrd {*}$args]
    uplevel 1 $args
}

proc command args {
    set args [action ecmd {*}$args]
    set args [action bcmd {*}$args]
    uplevel 1 $args
}

proc space args {
    set args [action ewrd {*}$args]
    set args [action bwrd {*}$args]
    uplevel 1 $args
}

proc success args {
    global cmddict ctxdict
    set args [action succ {*}$args]
    foreach k [lsort -integer [dict keys $cmddict]] {
        puts [format {%d: %s} $k [dict get $cmddict $k]]
    }
    foreach k [lsort -integer [dict keys $ctxdict]] {
        puts [format {%d: %s} $k [dict get $ctxdict $k]]
    }
}
