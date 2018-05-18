package require string::token

proc iterate args {
    for {set i 0} {$i < [llength $args]} {incr i} {
        set a [lindex $args $i]
        switch $a {
            init {
                action $a
            }
            enter {
                action bctx [lindex $args [incr i]]
            }
            leave {
                action ectx
            }
            command {
                action ecmd
                action bcmd
            }
            space {
                action ewrd
                action bwrd
            }
            add {
                action awrd [lindex $args [incr i]]
            }
            success {
                action succ [lindex $args [incr i]]
                report
            }
            default {
                ;
            }
        }
    }
}

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
                        emit [format {command %s: expression argument "%s"} $cmdtype [stringize $word]]
                    } elseif {$cmdwix eq 2} {
                        emit [format {command %s: script argument "%s"} $cmdtype [stringize $word]]
                    }
                }
                default {
                    if {$cmdwix eq 0} {
                        emit command $word
                    }
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
