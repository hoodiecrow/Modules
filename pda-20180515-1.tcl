package require string::token

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
            if no {
            if {[lindex [dict get $ctxdict $ctxnum] 0] ne "B"} {
            }
            }
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
            set cmdidx [lindex $commands 0]
            dict lappend cmddict $cmdidx $word
            set cmdwix [expr {[llength [dict get $cmddict $cmdidx]] - 1}]
            set cmdtype [lindex [dict get $cmddict $cmdidx] 0]
            switch $cmdtype {
                if - while {
                    if {$cmdwix eq 1} {
                        puts [format {command %s: expression argument "%s"} $cmdtype [stringize $word]]
                    } elseif {$cmdwix eq 2} {
                        puts [format {command %s: script argument "%s"} $cmdtype [stringize $word]]
                    }
                }
                default {
                    ;
                }
            }
            set ctxidx [lindex $contexts 0]
            set ctxtype [lindex [dict get $ctxdict $ctxidx] 0]
            puts [format {command %2d/%d in %2d%s: "%s"} $cmdidx $cmdwix $ctxidx $ctxtype $word]
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
    set args [action succ {*}$args]
    report
}

proc report {} {
    global cmddict ctxdict
    foreach k [lsort -integer [dict keys $cmddict]] {
        puts [format {%d: %s} $k [dict get $cmddict $k]]
    }
    foreach k [lsort -integer [dict keys $ctxdict]] {
        puts [format {%d: %s} $k [dict get $ctxdict $k]]
    }
}

proc stringize word {
    global ctxdict cmddict
    if no {
            cmdref { append res ($string) }
    }
    set lex {
        {<\d+>}   ctxref
        {\(\d+\)} cmdref
        {[^<(]+}  other
    }
    set res {}
    foreach token [string::token text $lex $word] {
        lassign $token type begin end
        set string [string range $word $begin $end]
        switch $type {
            ctxref {
                set string [string trim $string <>]
                set ctx [dict get $ctxdict $string]
                if {[lindex $ctx 0] eq "B"} {
                    append res C\($string)
                } else {
                    append res C\([join [stringize [join [lrange $ctx 1 end]]]])
                }
            }
            cmdref {
                set cmd [dict get $cmddict [string trim $string ()]]
                append res [join [stringize [join $cmd]]]
            }
            default {
                append res $string
            }
        }
    }
    return $res
}
