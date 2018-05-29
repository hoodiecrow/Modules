proc action {action {str {}}} {
    global result word commands contexts cmdnum ctxnum cmddict ctxdict
    switch $action {
        init {
            emit -clear
            set result {}
            set word {}
            set commands {}
            set cmdnum 0
            set cmddict {}
            set contexts {}
            set ctxnum 0
            set ctxdict {}
            action BeginContext S
        }
        enter {
            action BeginContext $str
            action BeginCommand
            action BeginWord
        }
        leave {
            action EndWord
            action EndCommand
            action EndContext
        }
        command {
            action EndWord
            action EndCommand
            action BeginCommand
            action BeginWord
        }
        space {
            action EndWord
            action BeginWord
        }
        add {
            append word $str
        }
        topic {
            dict lappend result topic $str
        }
        succ {
            action EndWord
            action EndCommand
            action EndContext
            action EndScript
        }
        BeginContext {
            incr ctxnum
            if {$str eq "B"} {
                dict set ctxdict $ctxnum [list [list B $word]]
            } else {
                dict set ctxdict $ctxnum [list $str]
            }
            set contexts [linsert $contexts 0 $ctxnum]
        }
        EndContext {
            set contexts [lassign $contexts idx]
            set word [lindex [dict get $ctxdict $idx] 0 1]¤$idx¤
        }
        BeginCommand {
            set commands [linsert $commands 0 [incr cmdnum]]
        }
        EndCommand {
            set commands [lassign $commands idx]
            dict lappend ctxdict [lindex $contexts 0] ($idx)
        }
        BeginWord {
            set word {}
        }
        EndWord {
            set cmdidx [lindex $commands 0]
            dict lappend cmddict $cmdidx $word
            set cmdwix [expr {[llength [dict get $cmddict $cmdidx]] - 1}]
            if {$cmdwix eq 0} {
                dict lappend result command $word
            } else {
                set name $word
                regexp {(?:::)?((?:::+|\w)+)} $name -> name
                dict lappend result variable $name
            }
            set cmdtype [lindex [dict get $cmddict $cmdidx] 0]
            switch $cmdtype {
                if - while {
                    if {$cmdwix eq 1} {
                        dict lappend result expressions [stringize $word]
                    }
                }
                for {
                    if {$cmdwix eq 2} {
                        dict lappend result expressions [stringize $word]
                    }
                }
                expr {
                    if {$cmdwix > 0} {
                        dict lappend result expressions [stringize $word]
                    }
                }
                package {
                    if {$cmdwix eq 2 && [lindex [dict get $cmddict $cmdidx] 1] eq "require"} {
                        dict lappend result package $word
                    }
                }
                default {
                }
            }
        }
        EndScript {
            emit $result
        }
        default {
            return -code error [format {illegal action "%s"} $action]
        }
    }
}

proc stringizeCommand word {
    global cmddict
    if {[regexp {\((\d+)\)} $word -> idx]} {
        return [join [dict get $cmddict $idx]]
    } else {
        return $word
    }
}

proc stringizeWord word {
    # TODO only allows for one context ref in a word: could be a problem with
    # command substitutions.
    global ctxdict
    if {[regexp {¤(\d+)¤} $word -> idx]} {
        set ctx [dict get $ctxdict $idx]
        lassign [lindex $ctx 0] type prefix
        if {$type eq "B"} {
            return ${prefix}CMDSUB
        } else {
            return [join [lmap w [lrange $ctx 1 end] {stringizeCommand $w}]]
        }
    } else {
        return $word
    }
}

proc stringize word {
    stringizeWord $word
}
