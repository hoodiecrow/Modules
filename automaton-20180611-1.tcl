
namespace eval automaton {
    variable tapes
    variable tapeid
}

oo::object create ::automaton::Reader
oo::objdefine ::automaton::Reader {
    method empty? str {expr {[llength $str] <= 0}}
    method get str {lindex $str 0}
    method rest str {lrange $str 1 end}
}

oo::object create ::automaton::Stack
oo::objdefine ::automaton::Stack {
    method pop varName {upvar 1 $varName stack ; set stack [lassign $stack A] ; return $A}
    method push {varName values} {upvar 1 $varName stack ; set stack [concat $values $stack] ; return}
}

oo::class create ::automaton::FSM {
    variable options transitions states alphabet
    constructor args {
        my AssignArgs $args options transitions
        set states [lsort -unique [lmap tuple $transitions {lindex $tuple 0}]]
        # TODO not actually used
        # TODO remove ε from alphabet
        set alphabet [lsort -unique [lmap tuple $transitions {lindex $tuple 1}]]
    }

    forward Reader ::automaton::Reader

    method AssignArgs {_args optVarName args} {
        upvar 1 $optVarName optvar
        while {[string match -* [lindex $_args 0]]} {
            if {[lindex $_args 0] eq "--"} {
                set _args [lrange $_args 1 end]
                break
            }
            set _args [lassign $_args opt optvar($opt)]
        }
        return [lassign $_args {*}$args]
    }

    method accept {state symbols acceptStates} {
        log::log d [info level 0] 
        if no {
            # TODO MoM output based on $state
            if {[my Reader empty? $symbols]} {
                return [expr {$state in $acceptStates}]
            } else {
                set results {}
                foreach trans [my matchTransition $state ε] {
                    log::log d ε-\$trans=$trans
                    lappend results [my accept [lindex $trans end] $symbols]
                }
                set a [my Reader get $symbols]
                # TODO MeM output based on $state/$a
                foreach trans [my matchTransition $state $a] {
                    log::log d \$trans=$trans
                    lappend results [my accept [lindex $trans end] [my Reader rest $symbols]]
                }
                return [expr {1 in $results}]
            }
        } else {
            # TODO MoM output based on $state
            set ss1 [list $state]
            set ss2 $ss1
            while {![my Reader empty? $symbols]} {
                log::log d statesets=[list $ss1]/[list $ss2]
                foreach s $ss1 {
                    foreach trans [my matchTransition $s ε] {
                        log::log d ε-\$trans=$trans
                        lappend ss1 [lindex $trans end]
                    }
                }
                set a [my Reader get $symbols]
                # TODO MeM output based on $state/$a
                set symbols [my Reader rest $symbols]
                set ss2 {}
                foreach s $ss1 {
                    foreach trans [my matchTransition $s $a] {
                        log::log d \$trans=$trans
                        lappend ss2 [lindex $trans end]
                    }
                }
                if {[llength $ss2] <= 0} {
                    return -code error [format {no transition for ((%s),%s)} [join $ss1 ,] $a]
                }
                set ss1 $ss2
            }
            log::log d \$ss2=$ss2
            foreach s $ss2 {
                if {$s in $acceptStates} {
                    return 1
                }
            }
            return 0
        }
    }

    method matchTransition args {
        set res $transitions
        for {set i 0} {$i < [llength $args]} {incr i} {
            set res [lsearch -all -inline -index $i $res [lindex $args $i]]
        }
        return $res
    }

}

oo::class create ::automaton::PDA {
    variable options transitions states alphabet stackAlphabet
    constructor args {
        my AssignArgs $args options transitions
        set states [lsort -unique [lmap tuple $transitions {lindex $tuple 0}]]
        # TODO not actually used
        # TODO remove ε from alphabet
        set alphabet [lsort -unique [lmap tuple $transitions {lindex $tuple 1}]]
        # TODO not actually used
        set stackAlphabet [lsort -unique [lmap tuple $transitions {lindex $tuple 2}]]
    }

    forward Reader ::automaton::Reader
    forward Stack ::automaton::Stack

    method AssignArgs {_args optVarName args} {
        upvar 1 $optVarName optvar
        while {[string match -* [lindex $_args 0]]} {
            if {[lindex $_args 0] eq "--"} {
                set _args [lrange $_args 1 end]
                break
            }
            set _args [lassign $_args opt optvar($opt)]
        }
        return [lassign $_args {*}$args]
    }

    method accept {Q symbols stack acceptStates} {
        set id [expr [clock microseconds]%1000]
        log::log d $id:[info level 0] 
        # if no transitions are made
        set T {}
        while 1 {
            # TODO MoM output based on $Q
            set symbols [lassign $symbols a]
            # TODO MeM output based on $state/$a
            if no {
                if {[llength $stack] eq 1} {
                    lassign $stack A
                } else {
                    set stack [lassign $stack A]
                }
            }
            set stack [lassign $stack A]
            if no {
                if {$A eq {}} {
                    set A ε
                }
            }
            log::log d "$id:\$Q=$Q, \$a=$a, \$A=$A, \$stack=$stack"
            foreach q $Q {
                set tuples [lsearch -all -inline -index 0 $transitions $q]
                set tuples [lsearch -all -inline -index 1 $tuples ε]
                set tuples [lsearch -all -inline -index 2 $tuples $A]
                foreach tuple $tuples {
                    lappend Q [lindex $tuple 3]
                }
            }
            set Q [lsort -unique $Q]
            log::log d $id:\$Q=$Q
            if {$a eq {}} {
                foreach q $Q {
                    if {$q in $acceptStates} {
                        return 1
                    }
                }
                return 0
            }
            set S {}
            foreach q $Q {
                set tuples [lsearch -all -inline -index 0 $transitions $q]
                set tuples [lsearch -all -inline -index 1 $tuples $a]
                lappend S {*}[lsearch -all -inline -index 2 $tuples $A]
            }
            log::log d $id:\$S=$S
            if {[llength $S] <= 0} {
                return 0
                return -code error [format {no transition for ((%s),%s,%s)} [join $Q ,] $a $A]
            }
            set T {}
            foreach s $S {
                lappend T [my accept [lindex $s 3] $symbols \
                    [concat {*}[string map {ε {}} [lrange $s 4 end]] $stack] \
                    $acceptStates]
            }
        }
        return [expr {1 in $T}]
    }

    method matchTransition args {
        set res $transitions
        for {set i 0} {$i < [llength $args]} {incr i} {
            set res [lsearch -all -inline -index $i $res [lindex $args $i]]
        }
        return $res
    }

}

oo::class create ::automaton::Head {
    variable tape alphabet position options _options
    constructor args {
        array set options {
            -readonly 0
            -sequential 0
            -leftward 1
            -rightward 1
            -infinite 1
            -leftinf 1
            -rightinf 1
            -blank _
            -leftedge <
            -rightedge >
        }
        set args [my SetOptions {*}$args]
        lassign $args t alphabet position
        set tape [my GetTape $t]
        if {$position eq {}} {
            set position 0
        }
        set illegal {}
        set legal $alphabet
        lappend legal $options(-blank) $options(-leftedge) $options(-rightedge)
        foreach sym $::automaton::tapes($tape) {
            if {$sym ni $legal} {
                lappend illegal $sym
            }
        }
        if {[llength $illegal] > 0} {
            return -code error [format {illegal symbol(s): %s} [join $illegal ", "]]
        }
        array set _options [array get options]
        my get
    }

    method GetTape t {
        if {!([llength $t] eq 1 && [string match tape* $t])} {
            set values $t
            set t ::automaton::tape[incr ::automaton::tapeid]
            set ::automaton::tapes($t) $values
        }
        return $t
    }

    method SetOptions args {
        while {[string match -* [lindex $args 0]]} {
            if {[lindex $args 0] eq "--"} {
                set args [lrange $args 1 end]
                break
            }
            set args [lassign $args opt options($opt)]
        }
        if {$options(-infinite)} {
            set options(-leftinf) 1
            set options(-rightinf) 1
        } else {
            set options(-leftinf) 0
            set options(-rightinf) 0
        }
        return $args
    }

    method Dump {} {
        list \
            $::automaton::tapes($tape) \
            $position
    }

    method configure args {
        foreach {opt val} $args {
            set options($opt) $val
        }
    }

    method get {} {
        if {$position > [llength $::automaton::tapes($tape)]} {
            set res {}
        } else {
            set res [lindex $::automaton::tapes($tape) $position]
            if {$res eq $options(-leftedge)} {
                set _options(-leftward) 0
                set _options(-readonly) 1
            } elseif {$res eq $options(-rightedge)} {
                set _options(-rightward) 0
                set _options(-readonly) 1
            } else {
                array set _options [array get options]
            }
        }
        return $res
    }

    method left {} {
        namespace upvar ::automaton tapes($tape) cells
        if {$_options(-leftward)} {
            if {$position < 1} {
                if {$_options(-leftinf)} {
                    set cells [linsert $cells 0 $options(-blank)]
                } else {
                    return -code error [format {no cells to the left}]
                }
            } else {
                incr position -1
            }
        }
        return [my get]
    }

    method right {} {
        namespace upvar ::automaton tapes($tape) cells
        if {$_options(-rightward)} {
            if {$position >= [llength $cells] - 1} {
                if {$_options(-rightinf)} {
                    lappend cells $options(-blank)
                    incr position
                } else {
                    if {$position > [llength $cells]} {
                        return -code error [format {no cells to the right}]
                    }
                    # allow head to move into cell beyond end
                    incr position
                }
            } else {
                incr position
            }
        }
        return [my get]
    }

    method set addr {
        if {!$_options(-sequential)} {
            if {[regexp {\*([+-]\d+)} $addr -> offset]} {
                incr position $offset
            } else {
                set position $addr
            }
        }
        return [my get]
    }

    method put val {
        if {$_options(-readonly)} {
            return -code error [format {attempting to write to readonly tape or cell}]
        }
        if {$val eq "blank"} {
            lset ::automaton::tapes($tape) $position $_options(-blank)
        } elseif {$val ni $alphabet} {
            return -code error [format {illegal symbol: %s} $val]
        } else {
            lset ::automaton::tapes($tape) $position $val
        }
        return [my get]
    }

}

package require tcltest
namespace import ::tcltest::*
package require log

test head-1.0 {} -body {
    set h [::automaton::Head new {a b} {a b c d}]
    set res {}
    lappend res [$h get] ; $h right
    lappend res [$h get] ; $h right
    set res
} -cleanup {
    $h destroy
} -result {a b}

test head-1.1 {} -body {
    set h [::automaton::Head new {a b} {a b c d} 1]
    set res {}
    lappend res [$h get] ; $h left
    lappend res [$h get] ; $h left
    set res
} -cleanup {
    $h destroy
} -result {b a}

test head-1.2 {} -body {
    set h [::automaton::Head new {a b} {a b c d} 0]
    set res {}
    lappend res [$h get] ; $h right
    lappend res [$h get] ; $h left
    lappend res [$h get] ; $h left
    set res
} -cleanup {
    $h destroy
} -result {a b a}

test head-1.3 {} -body {
    set h [::automaton::Head new {a b} {a b c d} 0]
    $h put X
} -result {illegal symbol: X} -returnCodes error

test head-1.4 {} -body {
    set h [::automaton::Head new {a b} {a b c d} 0]
    set res {}
    lappend res [$h get] ; $h right
    $h put d
    lappend res [$h get] ; $h left
    lappend res [$h get] ; $h left
    set res
} -cleanup {
    $h destroy
} -result {a d a}

test head-1.5 {} -body {
    set h [::automaton::Head new {a b} {a b c d} 1]
    set res {}
    lappend res [$h get] ; $h set *-1
    lappend res [$h get] ; $h set 1
    lappend res [$h get]
    set res
} -cleanup {
    $h destroy
} -result {b a b}

test tape-1.0 {} -body {
    ::automaton::Head create foo {a b c} {a b c} 2
    oo::objdefine foo export Dump
    foo Dump
} -cleanup {
    foo destroy
    log::lvSuppressLE i 1
} -result {{a b c} 2}

test tape-1.1 {} -body {
    ::automaton::Head create foo {a b c} {a b c} 2
    foo right ; foo left ; foo left ; foo left ; foo left
    oo::objdefine foo export Dump
    foo Dump
} -cleanup {
    foo destroy
    log::lvSuppressLE i 1
} -result {{_ a b c _} 0}

test tape-1.2e {} -body {
    ::automaton::Head create foo -infinite 0 {a b c _} {a b c} 2
    foo right ; foo left ; foo left ; foo left ; foo left
    oo::objdefine foo export Dump
    foo Dump
} -cleanup {
    foo destroy
    log::lvSuppressLE i 1
} -result {no cells to the left} -returnCodes error

test tape-1.2 {} -body {
    ::automaton::Head create foo -leftinf 0 {a b c} {a b c} 2
    foo right ; foo left ; foo left ; foo left
    oo::objdefine foo export Dump
    foo Dump
} -cleanup {
    foo destroy
    log::lvSuppressLE i 1
} -result {{a b c _} 0}

#

test tape-1.4a {} -body {
    ::automaton::Head create foo {a b c} {a b c}
    foo left ; foo put x
    oo::objdefine foo export Dump
    foo Dump
} -cleanup {
    foo destroy
    log::lvSuppressLE i 1
} -result {illegal symbol: x} -returnCodes error

test tape-1.4 {} -body {
    ::automaton::Head create foo {a b c} {a b c x} 2
    foo left ; foo put x
    oo::objdefine foo export Dump
    foo Dump
} -cleanup {
    foo destroy
    log::lvSuppressLE i 1
} -result {{a x c} 1}

test tape-1.5 {} -body {
    ::automaton::Head create foo {a b c} {a b c} 2
    foo left ; foo put blank
    oo::objdefine foo export Dump
    foo Dump
} -cleanup {
    foo destroy
    log::lvSuppressLE i 1
} -result {{a _ c} 1}

test tape-1.6 {} -body {
    ::automaton::Head create foo -blank X {a b c} {a b c} 2
    foo left ; foo put blank
    oo::objdefine foo export Dump
    foo Dump
} -cleanup {
    foo destroy
    log::lvSuppressLE i 1
} -result {{a X c} 1}

# tape-1.7 - tape-1.11

test tape-1.12 {} -body {
    ::automaton::Head create foo {< a b c _ _ _ _ >} {a b c}
    foo put blank
    oo::objdefine foo export Dump
    foo Dump
} -cleanup {
    foo destroy
    log::lvSuppressLE i 1
} -result {attempting to write to readonly tape or cell} -returnCodes error

test tape-1.13 {} -body {
    ::automaton::Head create foo {< a b c _ _ _ _ >} {a b c}
    foo left
    oo::objdefine foo export Dump ; foo Dump
} -cleanup {
    foo destroy
    log::lvSuppressLE i 1
} -result {{< a b c _ _ _ _ >} 0}

test tape-1.14 {} -body {
    ::automaton::Head create foo {< a b c _ _ _ _ >} {a b c} 8
    foo put blank
    oo::objdefine foo export Dump
    foo Dump
} -cleanup {
    foo destroy
    log::lvSuppressLE i 1
} -result {attempting to write to readonly tape or cell} -returnCodes error

test tape-1.15 {} -body {
    ::automaton::Head create foo {< a b c _ _ _ _ >} {a b c} 8
    foo right
    oo::objdefine foo export Dump ; foo Dump
} -cleanup {
    foo destroy
    log::lvSuppressLE i 1
} -result {{< a b c _ _ _ _ >} 8}

test dfa-1.0 {} -body {
    ::automaton::FSM create M {
        {s0 0 s0}
        {s0 1 s1}
        {s1 0 s2}
        {s1 1 s0}
        {s2 0 s1}
        {s2 1 s2}
    }
    M accept s0 {} {s0}
} -cleanup {
    M destroy
    log::lvSuppressLE i 1
} -result 1

test dfa-1.1 {} -body {
    ::automaton::FSM create M {
        {s0 0 s0}
        {s0 1 s1}
        {s1 0 s2}
        {s1 1 s0}
        {s2 0 s1}
        {s2 1 s2}
    }
    set res {}
    lappend res [M accept s0 {1} {s0}]
    lappend res [M accept s0 {0 1} {s0}]
    lappend res [M accept s0 {1 1} {s0}]
    lappend res [M accept s0 {0 0 1} {s0}]
    lappend res [M accept s0 {1 0 1} {s0}]
    lappend res [M accept s0 {0 1 1} {s0}]
    lappend res [M accept s0 {1 1 1} {s0}]
    set res
} -cleanup {
    M destroy
    log::lvSuppressLE i 1
} -result {0 0 1 0 0 1 0}

test nfa-1.0 {} -body {
    ::automaton::FSM create M {
        {s0 0 s0}
        {s0 1 s0}
        {s0 1 s1}
    }
    set res {}
    lappend res [M accept s0 {1} {s1}]
    lappend res [M accept s0 {0} {s1}]
    lappend res [M accept s0 {1 1} {s1}]
    lappend res [M accept s0 {1 0} {s1}]
    lappend res [M accept s0 {0 1} {s1}]
    lappend res [M accept s0 {0 0} {s1}]
    set res
} -cleanup {
    M destroy
    log::lvSuppressLE i 1
} -result {1 0 1 0 1 0}

test nfa-1.1 {find even number of ones/zeros} -body {
    ::automaton::FSM create M {
        {s0 ε s1}
        {s0 ε s3}
        {s1 0 s2}
        {s1 1 s1}
        {s2 0 s1}
        {s2 1 s2}
        {s3 0 s3}
        {s3 1 s4}
        {s4 0 s4}
        {s4 1 s3}
    }
    set res {}
    lappend res [M accept s0 {1 1} {s1 s3}]
    lappend res [M accept s0 {1 0} {s1 s3}]
    lappend res [M accept s0 {0 1} {s1 s3}]
    lappend res [M accept s0 {0 0} {s1 s3}]
    lappend res [M accept s0 {1 0 0 1 1 1} {s1 s3}]
    lappend res [M accept s0 {1 0 0 1 1 0} {s1 s3}]
    set res
} -cleanup {
    M destroy
    log::lvSuppressLE i 1
} -result {1 0 0 1 1 0}

test pda-1.1 {} -body {
    ::automaton::PDA create M {
        {p 0 Z p A Z}
        {p 0 A p A A}
        {p ε Z q Z}
        {p ε A q A}
        {q 1 A q ε}
        {q ε Z r Z}
    }
    set res {}
    log::lvSuppressLE i 0
    lappend res [M accept {p} {0 1} {Z} {r}]
    log::lvSuppressLE i 1
    lappend res [M accept {p} {0 0 0 1 1 1} {Z} {r}]
    lappend res [M accept {p} {0 0 0 1 1} {Z} {r}]
    set res
} -cleanup {
    M destroy
    log::lvSuppressLE i 1
} -result {1 1 0}

cleanupTests

