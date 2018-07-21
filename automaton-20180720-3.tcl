
# http://wiki.tcl-lang.org/20308

namespace eval FSM {
    namespace export *
}

catch { ::FSM::Runner destroy }
oo::class create ::FSM::Runner {
    variable current
    method Run {start accept inputs} {
        set current $start
        foreach input $inputs {
            set current [$current newState $input]
        }
        return [expr {$current in $accept}]
    }
    forward run my Run $_start $_accept
}

catch { rename ::FSM::State {} }
proc ::FSM::State {ns name body} {
    namespace eval ::FSM::Temp {
        variable transMat {}
        proc transition {input state} {
            variable transMat
            dict set transMat $input $state
        }
    }
    namespace eval ::FSM::Temp $body
    set o [oo::object create $ns\::$name]
    oo::objdefine $o [format {
        method newState input {
            dict get {
                %s
            } $input
        }
    } $::FSM::Temp::transMat]
    namespace delete ::FSM::Temp
    return $o
}

catch { rename ::FSM::Machine {} }
proc ::FSM::Machine {name body} {
    log::log d [info level 0] 
    variable _start {}
    variable _accept {}
    set ns [uplevel 1 {namespace current}]
    set o [oo::object create $ns\::$name]
    interp alias {} ::oo::objdefine::State {} ::FSM::State [info object namespace $o]
    interp alias {} ::oo::objdefine::start {} set [namespace which -variable _start]
    interp alias {} ::oo::objdefine::accept {} set [namespace which -variable _accept]
    oo::objdefine $o $body
    oo::objdefine $o mixin Runner
    foreach cmd {State start accept} {
        interp alias {} ::oo::objdefine::$cmd {}
    }
    return $o
}

namespace import ::FSM::*

catch { M destroy }

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
