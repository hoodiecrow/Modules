        proc parseExpressions strs {
            global data explex
            if {![info exists explex]} {
                set explex [dbMakeExpLex]
            }
            foreach str $strs {
                foreach tok [tokenize $explex $str] {
                    set label [lindex $tok 0]
                    if {$label ni {w _}} {
                        foreach type {operator function} {
                            foreach id [dbGetRowIds $type $label] {
                                dict incr data $id
                            }
                        }
                    }
                }
            }
        }
        proc action {what {str {}}} {
            global data word commands contexts cmdnum ctxnum cmddict ctxdict
            switch $what {
                init {
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
                succ {
                    action ewrd
                    action ecmd
                    action ectx
                    action escr
                }
                bctx {
                    incr ctxnum
                    dict set ctxdict $ctxnum [list $str]
                    set contexts [linsert $contexts 0 $ctxnum]
                }
                ectx {
                    set contexts [lassign $contexts idx]
                    set word <$idx>
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
                        dict lappend ::output commands $word
                    }
                    switch $cmdtype {
                        if - while {
                            if {$cmdwix eq 1} {
                                if no {
                                my Note [format {command %s: expression argument "%s"} $cmdtype [stringize $word]]
                                }
                                dict lappend ::output expressions [stringize $word]
                            }
                        }
                        default {
                        }
                    }
                    set ctxidx [lindex $contexts 0]
                    set ctxtype [lindex [dict get $ctxdict $ctxidx] 0]
                }
                escr {
                    dict for {k v} $::output {
                        dict set ::output $k [lsort -unique -dictionary $v]
                    }
                    if no {
                    emit {*}$::output
                    }
                    try {
                        parseExpressions [dict get $::output expressions]
                        set ids [dbGetRowIds command {*}[dict get $::output commands]]
                        foreach id $ids {
                            dict incr data $id
                        }
                    } on error msg {
                        emit $msg
                    }
                    if no {
                    emit [lsort -integer [dict keys $data]]
                    }
                    emit [join [lmap rowid [lsort -integer [dict keys $data]] {dbGet $rowid}] \n]
                }
                default {
                    ;
                }
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
            foreach token [tokenize $lex $word] {
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
