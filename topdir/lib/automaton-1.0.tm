
namespace eval automaton {}

oo::class create ::automaton::Utils {
    variable transitions output out

    method AssignArgs {arglist optVarName args} {
        upvar 1 $optVarName optvar
        foreach arg $args {
            upvar 1 $arg $arg
        }
        while {[string match -* [lindex $arglist 0]]} {
            if {[lindex $arglist 0] eq "--"} {
                set arglist [lrange $arglist 1 end]
                break
            }
            set arglist [lassign $arglist opt optvar($opt)]
        }
        return [lassign $arglist {*}$args]
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

    method MatchTransition {Q args} {
        log::log d [info level 0] 
        # get all tuples that match any of the state symbols
        set res [lsearch -regexp -all -inline -index 0 $transitions [join $Q |]]
        log::log d \$res=$res 
        # get all tuples that match input symbols/stack symbols etc
        for {set i 0} {$i < [llength $args]} {incr i} {
            set res [lsearch -all -inline -index $i+1 $res [lindex $args $i]]
        }
        log::log d \$res=$res 
        return $res
    }

}

oo::class create ::automaton::FSM {
    mixin ::automaton::Utils

    variable options transitions output out

    constructor args {
        my AssignArgs $args options transitions output out
    }

    method accept {Q symbols acceptStates} {
        while {[llength $symbols] > 0} {
            my OutputState $Q $symbols
            set symbols [lassign $symbols a]
            set Q [my ε-moves $Q 2]
            set S [my MatchTransition $Q $a]
            set Q [lsort -unique [lmap s $S {lindex $s 2}]]
        }
        return [my Accepting $Q {} $acceptStates]
    }

}

oo::class create ::automaton::PDA {
    mixin ::automaton::Utils

    variable options transitions output out

    constructor args {
        my AssignArgs $args options transitions output out
    }

    method accept {q symbols stack acceptStates} {
        # must be recursive because of stack
        my OutputState [list $q] $symbols $stack
        set symbols [lassign $symbols a]
        set stack [lassign $stack A]
        set Q [my ε-moves [list $q] 3 $A]
        if {$a eq {}} {
            return [my Accepting $Q [list $a $A] $acceptStates]
        }
        set S [my MatchTransition $Q $a $A]
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

oo::class create ::automaton::Base {
    variable data options head values

    constructor args {
        array set options {
            -values {}
            -start -1
            -blank _
            -length -1
            -leftbound 0
            -rightbound -1
            -endmarkers {}
            -fill 0
        }
        set args [my SetOptions {*}$args]
        set values [my SetValues $options(-values)]
        set head 0
        set data {}
        my WriteFill
        my WriteInitialValues $args
        my ResetHead
    }

    method WriteFill {} {
        if {[llength $options(-endmarkers)] > 0 && $options(-fill) > 0} {
            set data [linsert $options(-endmarkers) 1 {*}[lrepeat $options(-fill) $options(-blank)]]
            if {$options(-start) < 1} {
                set options(-start) 1
            } elseif {$options(-start) >= [llength $data]} {
                set options(-start) [expr {[llength $data] - 1}]
            } else {
                incr options(-start)
            }
            set head 1
        }
    }

    method WriteInitialValues vals {
        foreach val $vals {
            my Update $val
            catch { my Right }
        }
    }

    method ResetHead {} {
        if {0 <= $options(-start) && $options(-start) < [llength $data]} {
            set head $options(-start)
        } else {
            set head [expr {[llength $data] - 1}]
        }
        if {$head < 0} {
            set head 0
        }
    }

    method SetOptions args {
        while {[string match -* [lindex $args 0]]} {
            if {[lindex $args 0] eq "--"} {
                set args [lrange $args 1 end]
                break
            }
            set args [lassign $args opt options($opt)]
        }
        if {[info exists options(-default)] && [llength $args] eq 0} {
            lappend args $options(-default)
        }
        return $args
    }

    method SetValues vals {
        set vals [lmap val $vals {lindex $val 0}]
        if {[llength $vals] > 0} {
            lappend vals $options(-blank) {*}$options(-endmarkers)
            if {[info exists options(-empty)]} {
                lappend vals $options(-empty)
            }
        }
        return $vals
    }

    method Read {} {
        lindex $data $head
    }

    method CheckValues val {
        if {[llength $values] > 0 && [lindex $val 0] ni $values} {
            return -code error \
                [format {illegal %s value "%s" not in "%s"} \
                    [string tolower [namespace tail [info object class [self object]]]] \
                    $val \
                    [join [lmap value $options(-values) {lindex $value 0}] {, }]]
        }
    }

    method CheckEndmarker {} {
        if {
            [llength $options(-endmarkers)] > 0 &&
            [lindex $data $head] in $options(-endmarkers)
        } then {
            return -code error [format {attempting to overwrite endmarker "%s"} [lindex $data $head]]
        }
    }

    method Update val {
        my CheckValues $val
        my CheckEndmarker
        lset data $head $val
        self
    }

    method Blank {} {
        lset data $head $options(-blank)
        return
    }

    method Data {} {
        return $data
    }

    method CutLeft {} {
        my Right
        set data [lrange $data $head end]
        set head 0
        return
    }

    method CutRight {} {
        my Left
        set data [lrange $data 0 $head]
        set head [expr {[llength $data] - 1}]
        return
    }

    method AtCapacity {} {
        if {$options(-length) >= 0} {
            expr {[llength $data] >= $options(-length)}
        } else {
            return 0
        }
    }

    method AtLeftMarker {} {
        expr {
            [llength $options(-endmarkers)] > 0 &&
            [lindex $data $head] eq [lindex $options(-endmarkers) 0]
        }
    }

    method AtLeftEdge {} {
        if {$options(-leftbound)} {
            expr {$head < 1}
        } else {
            return 0
        }
    }

    method Left {} {
        if {[my AtLeftMarker]} {
            return -code error [format {attempted to move left beyond end marker}]
        }
        if {![my AtLeftEdge]} {
            incr head -1
        }
        return
    }

    method AtRightMarker {} {
        expr {
            [llength $options(-endmarkers)] > 0 &&
            [lindex $data $head] eq [lindex $options(-endmarkers) 1]
        }
    }

    method AtRightEdge {} {
        if {$options(-rightbound) >= 0} {
            expr {$head >= $options(-rightbound) - 1}
        } else {
            return 0
        }
    }

    method Right {} {
        if {[my AtRightMarker]} {
            return -code error [format {attempted to move right beyond end marker}]
        }
        if {![my AtRightEdge]} {
            incr head
        }
        return
    }

}

oo::class create ::automaton::Tape {
    superclass ::automaton::Base

    variable data options head

    constructor args {
        next {*}$args
    }

    forward get my Read
    forward set my Update
    forward erase my Blank
    method L {} {
        my Left
        if {$head < 0} {
            if {![my AtCapacity] && ![my AtLeftEdge]} {
                set data [linsert $data 0 $options(-blank)]
            }
            set head 0
        }
    }
    method R {} {
        my Right
        if {$head >= [llength $data]} {
            if {![my AtCapacity] && ![my AtRightEdge]} {
                my Update $options(-blank)
            }
            set head [expr {[llength $data] - 1}]
        }
    }
    method J addr {
        # TODO check edges and markers
        if {[string match {\**} $addr]} {
            incr head [string range $addr 1 end]
        } else {
            set head $addr
        }
    }
    export L R J

}

oo::class create ::automaton::Stack {
    # A tape with protocol
    # * blank value is always empty string
    # * bounded left
    # * begins with -start value iff no values given
    # * create/new with {-start X} is same as with {X}
    # * delegate tape's head is always in rightmost position
    # * pop operation reads and then removes rightmost element
    # * leftmost element can't be removed
    # * push operation repeatedly moves right and writes values
    # * adjust operation pops, then pushes values in reverse order
    superclass ::automaton::Base

    variable data options head

    constructor args {
        array set options {
            -default {}
        }
        next -blank {} -leftbound 1 {*}$args
    }

    method top {} {
        my Read
    }

    method pop {} {
        set val [my Read]
        my CutRight
        return $val
    }

    method push args {
        foreach arg $args {
            my Right
            my Update $arg
        }
    }

    method adjust args {
        if {[llength $args] eq 1 && [lindex $args 0] eq "-"} {
            return
        }
        my pop
        my push {*}[lreverse $args]
    }

}

oo::class create ::automaton::Input {
    # A tape with protocol
    # * $options(-start) added at end of $args
    # * create/new with {-start X} is same as with {X}
    # * no writing or adding elements
    # * no left movement
    # * always starts at 0
    # * every read advances right
    superclass ::automaton::Base

    variable data options head hasTokens

    constructor args {
        array set options {
            -empty \u03b5
        }
        next -start 0 {*}$args
        lappend data $options(-empty)
        set options(-rightbound) [llength $data]
        set hasTokens 1
    }

    method hasTokens {} {
        return $hasTokens
    }

    method get {} {
        set val [my Read]
        if {[my AtRightEdge]} {
            set hasTokens 0
        }
        my Right
        return $val
    }

}

oo::class create ::automaton::State {
    # Behavior
    # get, set, accept
    # no movement
    # -default (start value)
    # -accept (list of accepting states)
    # ignore all Base options except -values -start -rightbound
    superclass ::automaton::Base

    variable data options values head

    constructor args {
        array set options {
            -accept {}
        }
        next -start 0 -rightbound 1 {*}$args
        my CheckAcceptStates
    }

    method CheckAcceptStates {} {
        set illegal {}
        foreach s $options(-accept) {
            if {$s ni $values} {
                lappend illegal $s
            }
        }
        if {[llength $illegal] > 0} {
            return -code error [format {illegal accepting state(s) (%s)} [join $illegal {, }]]
        }
    }

    method incr {{n 1}} {
        set v [my Read]
        incr v $n
        if {$v > $options(-limit)} {
            return -code error [format {value overflow: %d} $v]
        }
        my Update $v
    }

    method get {} {
        my Read
    }

    method set val {
        my Update $val
    }

    method accept {} {
        expr {[my Read] in $options(-accept)}
    }

}
