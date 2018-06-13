
namespace eval automaton {
    variable tapes
    variable tapeid
}

oo::object create ::automaton::Reader
oo::objdefine ::automaton::Reader {
    method empty? str {expr {[llength $str] <= 0}}
    method get {str varName} {upvar 1 $varName var ; lassign $str var}
    method rest str {lrange $str 1 end}
}

oo::class create ::automaton::Utils {
    variable transitions output out

    method AssignArgs {_args optVarName args} {
        upvar 1 $optVarName optvar
        foreach arg $args {
            upvar 1 $arg $arg
        }
        while {[string match -* [lindex $_args 0]]} {
            if {[lindex $_args 0] eq "--"} {
                set _args [lrange $_args 1 end]
                break
            }
            set _args [lassign $_args opt optvar($opt)]
        }
        return [lassign $_args {*}$args]
    }

    method output {} {set out}

    method OutputByKey k {
        if {[dict exists $output $k]} {
            lappend out [dict get $output $k]
        }
    }

    method OutputByID args {
        set k [join [lmap arg $args {lindex $arg 0}] ,]
        if {[string first , $k] < 0} {
            set k $k,
        }
        my OutputByKey $k
    }

    method OutputState {Q args} {
        log::log d [format {stateset=((%s),%s)} \
            $Q \
            [join [lmap arg $args {lindex $arg 0}] ,]]
        if {$output ne {}} {
            foreach q $Q {
                my OutputByKey $q
                my OutputByID $q {*}$args
            }
        }
    }

    method Accepting {Q a acceptStates} {
        foreach q $Q {
            if {$q in $acceptStates} {
                if {$output ne {}} {
                    my OutputByKey $q
                    my OutputByID $q {*}$a
                }
                return 1
            }
        }
        return 0
    }

    method ε-moves {Q idx {A {}}} {
        foreach q $Q {
            set tuples [my MatchTransition $q ε]
            if {$A ne {}} {
                set tuples [lsearch -all -inline -index 2 $tuples $A]
            }
            foreach tuple $tuples {
                lappend Q [lindex $tuple $idx]
            }
        }
        return [lsort -unique $Q]
    }

    method MatchTransition args {
        set res $transitions
        for {set i 0} {$i < [llength $args]} {incr i} {
            set res [lsearch -all -inline -index $i $res [lindex $args $i]]
        }
        return $res
    }

}

oo::class create ::automaton::FSM {
    mixin ::automaton::Utils

    variable options transitions output out states alphabet

    constructor args {
        my AssignArgs $args options transitions output out
        set states [lsort -unique [lmap tuple $transitions {lindex $tuple 0}]]
        # TODO not actually used
        # TODO remove ε from alphabet
        set alphabet [lsort -unique [lmap tuple $transitions {lindex $tuple 1}]]
    }

    forward Reader ::automaton::Reader

    method accept {Q symbols acceptStates} {
        log::log d [info level 0]
        set a {}
        while {![my Reader empty? $symbols]} {
            my OutputState $Q $symbols
            set symbols [my Reader get $symbols a]
            set Q [my ε-moves $Q 2]
            set S [concat {*}[lmap q $Q {my MatchTransition $q $a}]]
            set Q [lmap s $S {lindex $s 2}]
        }
        return [my Accepting $Q {} $acceptStates]
    }

}

oo::class create ::automaton::PDA {
    mixin ::automaton::Utils

    variable options transitions output out states alphabet stackAlphabet

    constructor args {
        my AssignArgs $args options transitions output out
        set states [lsort -unique [lmap tuple $transitions {lindex $tuple 0}]]
        # TODO not actually used
        # TODO remove ε from alphabet
        set alphabet [lsort -unique [lmap tuple $transitions {lindex $tuple 1}]]
        # TODO not actually used
        set stackAlphabet [lsort -unique [lmap tuple $transitions {lindex $tuple 2}]]
    }

    method accept {q symbols stack acceptStates} {
        # must be recursive because of stack
        set id [expr [clock microseconds]%1000] ; log::log d $id:[info level 0] 
        my OutputState [list $q] $symbols $stack
        if no {
            log::log d "stateset=($q,[lindex $symbols 0],$stack)"
            if {$output ne {}} {
                my OutputByKey $q
                my OutputByID $q $symbols $stack
            }
        }
        set symbols [lassign $symbols a]
        set stack [lassign $stack A]
        set Q [my ε-moves [list $q] 3 $A]
        if {$a eq {}} {
            return [my Accepting $Q [list $a $A] $acceptStates]
        }
        set S [concat {*}[lmap q $Q {my MatchTransition $q $a $A}]]
        foreach s $S {
            if {[lindex $s end 0] eq "ε"} {
                set s [lrange $s 0 3]
            }
            set α [lassign $s - - - p]
            if {[my accept $p $symbols [concat ${α} $stack] $acceptStates]} {
                return 1
            }
        }
        return 0
    }

}
