
# http://wiki.tcl-lang.org/20308

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

proc Machine {name body} {
    log::log d [info level 0] 
    variable _start {}
    variable _accept {}
    set ns [uplevel 1 {namespace current}]
    set o [oo::object create $ns\::$name]
    interp alias {} ::oo::objdefine::State {} {*}[namespace code {apply {{ns name body} {
        set o [uplevel 1 [list ::CState create $ns\::$name]]
        oo::objdefine $o $body
    }}}] [info object namespace $o]
    log::log d [interp alias {} ::oo::objdefine::State]
    interp alias {} ::oo::objdefine::start {} set [namespace which -variable _start]
    interp alias {} ::oo::objdefine::accept {} set [namespace which -variable _accept]
    oo::objdefine $o $body
    oo::objdefine $o variable current
    foreach cmd {State start accept} {
        interp alias {} ::oo::objdefine::$cmd {}
    }
    oo::objdefine $o method step input {
        set current [$current newState $input]
    }
    oo::objdefine $o method Run {start accept inputs} {
        set current $start
        foreach input $inputs {
            my step $input
        }
        return [expr {$current in $accept}]
    }
    oo::objdefine $o forward run my Run $_start $_accept
}


proc ::oo::objdefine::transition {input state} {
    set o [lindex [info level -1] 1]
    tailcall dict set [info object namespace $o]::transMat $input $state
}

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

return

state label state-body
entry action
exit action
transition trigger nextState ?action? ;# action is a script
internal trigger ?action?
choice expr0 clause0 ?exprN clauseN? elseClause ;# clause = {nextState ?action?}
input source ?source...?
start label ?action?
accept label ?label...?

state-body
entry
exit
transition
internal

in a hierarchical SM going to state {} means returning to outer level
orthogonal states
Internal transitions
self-transitions (does entry/exit action)
Local versus external transitions
Event deferral

composite states can have a set entry state, or re-enter the last state they had

event firing: exit action of current state, action of transition, entry action of new state

state stack for composite states: pop off and exit, transition, entry and push


event                               ;# different event classes generating event instances -- possibly stick to input stream

???:
FSM: create a machine instance
state (running in FSM): create a State class from which state instances can be created
transition: add a transition method to the State class being defined
accept: set the accept attribute of the State class to 1
