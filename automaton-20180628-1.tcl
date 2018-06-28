package require log

catch {State destroy}
oo::class create State {
    constructor args {
        my OnEnter
    }

    destructor {
        my OnLeave
    }

    method OnEnter args {
        log::log d "enter state [self object] [namespace tail [info object class [self]]]"
    }

    method OnLeave args {
        log::log d "leave state [self object] [namespace tail [info object class [self]]]"
    }

    # there will be one call to OnTransition for every symbol and target
    method OnTransition {symbol target trans} {
        set str "move [self object] ([namespace tail [info object class [self]]],$symbol) "
        append str "-> $target ([namespace tail [info object class $target]])"
        log::log d $str
        if {$trans ne {}} {
            # do transition action
        }
        return $target
    }

    method ε-moves {} { list [self] }
    export ε-moves

    # there will be one public move-> method for each symbol, with potentially
    # multiple targets
    method Move {symbol args} {
        return [lmap arg $args {
            lassign $arg state trans
            my OnTransition $symbol [$state new] $trans
        }]
    }

    if no {
        method move->symbol {
            # transition action according to symbol
            # return list of state instance(s) or {}
        }
    }

    method unknown args {
        switch -glob [lindex $args 0] {
            move->* {
                return
            }
            isAccepting {
                return 0
            }
            default {
                next {*}$args
            }
        }
    }

}

catch {FSM destroy}
oo::class create FSM {
    variable paths

    constructor args {
        set paths $args
    }

    method accept {input output} {
        while {[$input get symbol] >= 0} {
            set states $paths
            set paths [list]
            foreach state $states {
                foreach move [$state ε-moves] {
                    lappend paths {*}[$state move->$symbol]
                }
                # do not destroy $state if no moves resulted from it
                if {$state ne [lindex $paths end]} {
                    $state destroy
                }
            }
        }
        set result [expr {1 in [lmap state $paths {$state isAccepting}]}]
        foreach state $paths {$state destroy}
        return $result
    }
}

catch {Input destroy}
oo::class create Input {
    # produce an input symbol from an input stream or an input stream and a
    # stack
    variable stream stack

    constructor args {
        lassign $args stream stack
    }

    method StreamGet {} {
        if {[llength $stream] > 0} {
            set stream [lassign $stream symbol]
            return $symbol
        } else {
            return -level 2 -1
        }
    }

    method get varName {
        upvar 1 $varName var
        if {$stack eq "--"} {
            set var [my StreamGet]
        } else {
            set var [my StreamGet],[my StackGet]
        }
        return 0
    }

}

# proc oo::Helpers::transition {symbol target}
    #set this [uplevel 1 {self object}]

proc oo::define::transition {symbol args} {
    # 'symbol' is one or more input tokens joined by ','
    # 'args' is the target states (State subclasses)
    set this [lindex [info level -1] 1]
    oo::define $this method move->$symbol {} [list my Move $symbol {*}$args]
}

oo::class create S0 {
    superclass State
    transition 1 S0
    transition 0 S1
    method isAccepting {} {return 1}
}

oo::class create S1 {
    superclass State
    transition 1 S1
    transition 0 S0
}

Input create inp [split 0010110 {}] --
FSM create M [S0 new]
puts "FSA: [M accept inp --]"
inp destroy
M destroy

Input create inp [split 00101100 {}] --
FSM create M [S0 new]
puts "FSA: [M accept inp --]"
inp destroy
M destroy
