        proc action {what {str {}}} {
            global output word commands contexts cmdnum ctxnum cmddict ctxdict
            switch $what {
                init {
                    emit -clear
                    set output {}
                    set word {}
                    set commands {}
                    set cmdnum 0
                    set cmddict {}
                    set contexts {}
                    set ctxnum 0
                    set ctxdict {}
                    action bctx S
                }
                enter {
                    action bctx $str
                    action bcmd
                    action bwrd
                }
                leave {
                    action ewrd
                    action ecmd
                    action ectx
                }
                command {
                    action ewrd
                    action ecmd
                    action bcmd
                    action bwrd
                }
                space {
                    action ewrd
                    action bwrd
                }
                add {
                    action awrd $str
                }
                topic {
                    dict lappend output topic $str
                }
                succ {
                    action ewrd
                    action ecmd
                    action ectx
                    action escr
                }
                bctx {
                    incr ctxnum
                    if {$str eq "B"} {
                        dict set ctxdict $ctxnum [list [list B $word]]
                    } else {
                        dict set ctxdict $ctxnum [list $str]
                    }
                    set contexts [linsert $contexts 0 $ctxnum]
                }
                ectx {
                    set contexts [lassign $contexts idx]
                    set word [lindex [dict get $ctxdict $idx] 0 1]¤$idx¤
                }
                bcmd {
                    incr cmdnum
                    set commands [linsert $commands 0 $cmdnum]
                }
                ecmd {
                    set commands [lassign $commands idx]
                    dict lappend ctxdict [lindex $contexts 0] ($idx)
                }
                bwrd {
                    set word {}
                }
                awrd {
                    append word $str
                }
                ewrd {
                    set cmdidx [lindex $commands 0]
                    dict lappend cmddict $cmdidx $word
                    set cmdwix [expr {[llength [dict get $cmddict $cmdidx]] - 1}]
                    set cmdtype [lindex [dict get $cmddict $cmdidx] 0]
                    if {$cmdwix eq 0} {
                        dict lappend output command $word
                    } else {
                        set name $word
                        regexp {(?:::)?((?:::+|\w)+)} $name -> name
                        dict lappend output variable $name
                    }
                    switch $cmdtype {
                        if - while {
                            if {$cmdwix eq 1} {
                                dict lappend output expressions [stringize $word]
                            }
                        }
                        for {
                            if {$cmdwix eq 2} {
                                dict lappend output expressions [stringize $word]
                            }
                        }
                        expr {
                            if {$cmdwix > 0} {
                                dict lappend output expressions [stringize $word]
                            }
                        }
                        package {
                            if {$cmdwix eq 2 && [lindex [dict get $cmddict $cmdidx] 1] eq "require"} {
                                dict lappend output package $word
                            }
                        }
                        default {
                        }
                    }
                    set ctxidx [lindex $contexts 0]
                    set ctxtype [lindex [dict get $ctxdict $ctxidx] 0]
                }
                escr {
                    emit $output
                }
                default {
                    ;
                }
            }
        }
        proc stringizeCommand word {
            global ctxdict cmddict
            if {[regexp {\((\d+)\)} $word -> idx]} {
                set res [join [lrange [dict get $cmddict $idx] 0 end]]
                return $res
            } else {
                return $word
            }
        }
        proc stringizeWord word {
            global ctxdict cmddict
            if {[regexp {¤(\d+)¤} $word -> idx]} {
                set ctx [dict get $ctxdict $idx]
                lassign [lindex $ctx 0] type prefix
                if {$type eq "B"} {
                    return ${prefix}CMDSUB
                } else {
                    set res [join [lmap w [lrange $ctx 1 end] {stringizeCommand $w}]]
                    return $res
                }
            } else {
                return $word
            }
        }
        proc stringize word {
            if no {
            emit [info level 0] 
            set result [try {stringizeWord $word} on error msg {set msg}]
            emit \$result=$result
            return $result
            } else {
            stringizeWord $word
            }
        }
