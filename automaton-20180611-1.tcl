
namespace eval automaton {
    variable tapes
    variable tapeid
}

oo::class create ::automaton::NFA {
    variable states begin acceptStates transitions head next options
    constructor args {
        array set options {
            -epsilon 0
        }
        set args [my SetOptions {*}$args]
        lassign $args states begin acceptStates transitions
        if {$begin ni $states} {
            return -code error [format {illegal starting state: %s} $begin]
        }
        my CheckAcceptStates
    }

    method SetOptions args {
        while {[string match -* [lindex $args 0]]} {
            if {[lindex $args 0] eq "--"} {
                set args [lrange $args 1 end]
                break
            }
            set args [lassign $args opt options($opt)]
        }
        return $args
    }

    method CheckAcceptStates {} {
        set illegal {}
        foreach s $acceptStates {
            if {$s ni $states} {
                lappend illegal $s
            }
        }
        if {[llength $illegal] > 0} {
            return -code error [format {illegal accepting state(s) (%s)} [join $illegal {, }]]
        }
    }

    method accept h {
        set head $h
        $head configure -readonly 1 -sequential 1 -leftward 0
        set ts {}
        # TODO MoM output based on begin
        if {$options(-epsilon)} {
            lappend ts {*}[my matchTransition $begin ε]
            # TODO MeM output based on begin/ε
        }
        set a [$head get]
        if {$a eq {}} {
            return [expr {$begin in $acceptStates}]
        }
        lappend ts {*}[my matchTransition $begin $a]
        log::log d \$ts=$ts 
        # TODO MeM output based on begin/$a
        set h0 [oo::copy $head]
        $head right
        foreach p [lsort -unique [lmap item $ts {lindex $item end}]] {
            set args {}
            lappend args {*}[array get options]
            lappend args $states $p $acceptStates
            set m [[self class] new {*}$args]
            if {$p eq "ε"} {
                m accept $h0
            } else {
                m accept $head
            }
            lappend next $m
        }
    }

    method matchTransition args {
        log::log d [info level 0] 
        set res $transitions
        log::log d \$res=$res 
        for {set i 0} {$i < [llength $args]} {incr i} {
            set arg [lindex $args $i]
            set res [lsearch -all -inline -index $i $res $arg]
            log::log d \$res=$res 
        }
        return $res
    }

}

# no ε-moves: ε-NFA for that
oo::class create ::automaton::DFA {
    variable states begin acceptStates transitions head next current options
    constructor args {
        array set options {
        }
        set args [my SetOptions {*}$args]
        lassign $args states begin acceptStates transitions
        if {$begin ni $states} {
            return -code error [format {illegal starting state: %s} $begin]
        }
        my CheckAcceptStates
        set current $begin
    }

    method SetOptions args {
        while {[string match -* [lindex $args 0]]} {
            if {[lindex $args 0] eq "--"} {
                set args [lrange $args 1 end]
                break
            }
            set args [lassign $args opt options($opt)]
        }
        return $args
    }

    method CheckAcceptStates {} {
        set illegal {}
        foreach s $acceptStates {
            if {$s ni $states} {
                lappend illegal $s
            }
        }
        if {[llength $illegal] > 0} {
            return -code error [format {illegal accepting state(s) (%s)} [join $illegal {, }]]
        }
    }

    method accept h {
        set head $h
        $head configure -readonly 1 -sequential 1 -leftward 0 -rightinf 0
        # TODO MoM output based on current
        set a [$head get]
        if {$a eq {}} {
            set final $current
            set current $begin
            return [expr {$final in $acceptStates}]
        }
        # TODO MeM output based on $current/$a
        $head right
        set current [lindex [my matchTransition $current $a] 0 end]
        log::log d \$current=$current 
        return [my accept $head]
    }

    method matchTransition args {
        log::log d [info level 0] 
        set res $transitions
        log::log d \$res=$res 
        for {set i 0} {$i < [llength $args]} {incr i} {
            set arg [lindex $args $i]
            set res [lsearch -all -inline -index $i $res $arg]
            log::log d \$res=$res 
        }
        # TODO error if more than one match
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
    ::automaton::DFA create M {s0 s1 s2} s0 {s0} {
        {s0 0 s0}
        {s0 1 s1}
        {s1 0 s2}
        {s1 1 s0}
        {s2 0 s1}
        {s2 1 s2}
    }
    M accept [::automaton::Head new {} {0 1}]
} -cleanup {
    M destroy
    log::lvSuppressLE i 1
} -result 1


test dfa-1.1 {} -body {
    ::automaton::DFA create M {s0 s1 s2} s0 {s0} {
        {s0 0 s0}
        {s0 1 s1}
        {s1 0 s2}
        {s1 1 s0}
        {s2 0 s1}
        {s2 1 s2}
    }
    set res {}
    lappend res [M accept [::automaton::Head new {1} {0 1}]]
    lappend res [M accept [::automaton::Head new {0 1} {0 1}]]
    lappend res [M accept [::automaton::Head new {1 1} {0 1}]]
    lappend res [M accept [::automaton::Head new {0 0 1} {0 1}]]
    lappend res [M accept [::automaton::Head new {1 0 1} {0 1}]]
    lappend res [M accept [::automaton::Head new {0 1 1} {0 1}]]
    lappend res [M accept [::automaton::Head new {1 1 1} {0 1}]]
    set res
} -cleanup {
    M destroy
    log::lvSuppressLE i 1
} -result {0 0 1 0 0 1 0}


cleanupTests

