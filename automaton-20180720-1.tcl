
if no {
    catch { Machine destroy }
    oo::class create Machine {
        constructor args {
            namespace eval [self namespace] {
                variable current
                proc start state {
                    variable current $state
                }
                proc accept args {
                    variable accept $args
                }
            }
            set script [lindex $args end]
            my eval $script
        }
        method step input {
            variable current
            set current [$current newState $input]
        }
    }

    catch { State destroy }
    oo::class create State {
        constructor args {
            namespace eval [self namespace] {
                variable transMat {}
                proc transition {input state} {
                    variable transMat
                    dict set transMat $input $state
                }
            }
            set script [lindex $args end]
            my eval $script
        }
        method newState input {
            variable transMat
            dict get $transMat $input
        }
    }

    Machine create M {
        State create S0 {
            transition 0 S1
            transition 1 S0
        }
        State create S1 {
            transition 0 S0
            transition 1 S1
        }
        start S0
        accept {S0}
    }
} elseif no {
    namespace eval fsm {
        namespace eval state {}
    }

    proc ::fsm::start state {
        tailcall variable current $state
    }

    proc ::fsm::accept args {
        tailcall variable accept $args
    }

    proc ::fsm::State {name body} {
        tailcall ::State create $name $body
    }

    proc ::fsm::state::transition {input state} {
        tailcall dict set transMat $input $state
    }

    catch { Machine destroy }
    oo::class create Machine {
        variable current
        constructor args {
            namespace path [linsert [namespace path] 0 ::fsm]
            set script [lindex $args end]
            my eval $script
        }
        method step input {
            set current [$current newState $input]
        }
    }

    catch { State destroy }
    oo::class create State {
        variable transMat
        constructor args {
            set transMat {}
            namespace path [linsert [namespace path] 0 ::fsm::state]
            set script [lindex $args end]
            my eval $script
        }
        method newState input {
            dict get $transMat $input
        }
    }

    Machine create M {
        State S0 {
            transition 0 S1
            transition 1 S0
        }
        State S1 {
            transition 0 S0
            transition 1 S1
        }
        start S0
        accept {S0}
    }
} else {

    proc Machine {name body} {
        set o [uplevel 1 [list ::CMachine create $name]]
        tailcall oo::objdefine $o $body
    }

    proc State {name body} {
        set o [lindex [info level -1] 1]
        set o [uplevel 1 [list ::CState create [info object namespace $o]::$name]]
        tailcall oo::objdefine $o $body
    }

    proc ::oo::objdefine::start state {
        set o [lindex [info level -1] 1]
        tailcall set [info object namespace $o]::start $state
    }

    proc ::oo::objdefine::accept args {
        set o [lindex [info level -1] 1]
        tailcall set [info object namespace $o]::accept $args
    }

    proc ::oo::objdefine::transition {input state} {
        set o [lindex [info level -1] 1]
        tailcall dict set [info object namespace $o]::transMat $input $state
    }

    catch { CMachine destroy }
    oo::class create CMachine {
        variable start current accept
        method step input {
            set current [$current newState $input]
        }
        method run inputs {
            set current $start
            foreach input $inputs {
                my step $input
            }
            return [expr {$current in $accept}]
        }
    }

    catch { CState destroy }
    oo::class create CState {
        variable transMat
        constructor args {
            set transMat {}
        }
        method newState input {
            dict get $transMat $input
        }
    }

    Machine M {
        State S0 {
            transition 0 S1
            transition 1 S0
        }
        State S1 {
            transition 0 S0
            transition 1 S1
        }
        start S0
        accept {S0}
    }
}
