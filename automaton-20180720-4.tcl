
# http://wiki.tcl-lang.org/20308

namespace eval ::FSM {
    namespace export *

    namespace eval inner {
        variable start {}
        variable accept {}
        variable transMat {}
        proc State {name body} {
            namespace eval ::FSM::inner [list interp alias {} transition {} dict set transMat $name]
            namespace eval ::FSM::inner $body
            namespace eval ::FSM::inner [list interp alias {} transition {}]
        }
        interp alias {} start {} variable start
        interp alias {} accept {} variable accept
    }

    oo::class create CMachine {
        variable start accept transMat current
        constructor args {
            lassign $args start accept transMat
        }
        method run inputs {
            set current $start
            foreach input $inputs {
                set current [dict get $transMat $current $input]
            }
            return [expr {$current in $accept}]
        }
    }

    proc Machine {name body} {
        namespace eval ::FSM::inner $body
        CMachine create [uplevel 1 {namespace current}]::$name $inner::start $inner::accept $inner::transMat
    }
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

return

Machine is a command {name body} that evaluates body in a namespace containing State, start, accept, transition. These commands assemble an argument list for the constructor of a CMachine class which implements FSM behavior.

---

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
