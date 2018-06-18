
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

    method OutputByKey {k args} {
        log::log d [info level 0] 
        if {[dict exists $output $k]} {
            lappend out [concat [dict get $output $k] $args]
        }
    }

    method OutputByID {state token args} {
        # Input symbols is always the first item in args, and the first item in
        # symbols has the input symbol to be used for the transition. If the
        # first item is a list, the tail of this list is to be appended to the
        # output. Only the first element of the item is the input symbol.
        set tail [lassign $token symbol]
        set k $state,$symbol
        if {[llength $args] > 0} {
            append k , [join [lmap arg $args {lindex $arg 0}] ,]
        }
        my OutputByKey $k {*}$tail
    }

    method OutputState {states symbols args} {
        set symbols [lassign $symbols token]
        log::log d [format {stateset=((%s),%s)} \
            $states \
            [join [linsert [lmap arg $args {lindex $arg 0}] 0 [lindex $token 0]] ,]]
        if {$output ne {}} {
            foreach state $states {
                my OutputByKey $state
                my OutputByID $state $token {*}$args
            }
        }
    }

    method Accepting {acceptStates states symbols args} {
        # only the first accepted state is reported
        set symbols [lassign $symbols token]
        foreach state $states {
            if {$state in $acceptStates} {
                if {$output ne {}} {
                    my OutputByKey $state
                    my OutputByID $state $token {*}$args
                }
                return 1
            }
        }
        return 0
    }

    method ε-moves {states idx {stack {}}} {
        set A [lindex $stack 0]
        foreach state $states {
            set tuples [my MatchTransition $state ε]
            if {$stack ne {}} {
                set tuples [lsearch -all -inline -index 2 $tuples $A]
            }
            foreach tuple $tuples {
                lappend states [lindex $tuple $idx]
            }
        }
        return [lsort -unique $states]
    }

    method MatchTransition {states args} {
        log::log d [info level 0] 
        # get all tuples that match any of the state symbols
        set tuples [lsearch -regexp -all -inline -index 0 $transitions [join $states |]]
        log::log d \$tuples=$tuples 
        # make the current input symbol atomic
        lset args 0 [lindex $args 0 0]
        # get all tuples that match input symbols/stack symbols etc
        if {[llength $args] > 0} {
            for {set i 0} {$i < [llength $args]} {incr i} {
                set tuples [lsearch -all -inline -index $i+1 $tuples [lindex $args $i 0]]
            }
        }
        log::log d \$tuples=$tuples 
        return $tuples
    }

}

oo::class create ::automaton::FSM2Moore {
    variable options transitions moves acceptStates output n tracks activeStates

    constructor args {
        my AssignArgs $args options transitions output
        set acceptStates {}
        foreach transition $transitions {
            lassign $transition from edge to
            if {[regexp {\(([^/\s]+)\)} $from -> acceptState]} {
                lappend acceptStates $acceptState
            }
            regexp {(\(?([^/\s]+)\)?)\s*/\s*(.*)} $from -> from output($from)
            regexp {([^/\s]+)\s*/\s*(.*)} $edge -> edge output($edge)
            lappend move($from,$edge) $to
        }
        set n 0
        set tracks {}
        set activeStates {}
    }

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

    method AddTrack {n state} {
        lassign [split $state /] state output
        dict set tracks $n state [string trim $state]
        dict lappend tracks $n output [string trim $output]
    }

    method ε-move data {
        dict for {n data} $tracks {
        }
    }

    method accept current {
        lassign $current tracks symbols
        while {[llength $symbols] > 0} {
            set symbols [lassign $symbols symbol]
            set new {}
            for {set i 0} {$i < [llength $tracks]} {incr i} {
                set track [lindex $tracks $i]
                if {$track eq {}} {
                    continue
                }
                set state [lindex $track end]
                if {[info exists move($state,ε)]} {
                    foreach to $move($state,ε) {
                        lappend new [lreplace $track end end $to]
                    }
                }
                lset tracks $i {}
                if {[info exists move($state,$symbol)]} {
                    foreach to $move($state,$symbol) {
                        lappend new [linsert $track end $to]
                    }
                }
            }
            set tracks [lmap track [concat $tracks $new] {
                if {$track eq {}} {
                    continue
                } else {
                    set track
                }
            }
        }
        foreach track $tracks {
            if {[lindex $track end] in $acceptStates} {
                puts [lmap state $track {set output($state)}]
            }
        }
    }

}

oo::class create ::automaton::FSM {
    mixin ::automaton::Utils

    variable options transitions output out

    constructor args {
        my AssignArgs $args options transitions output out
    }

    method accept {states symbols acceptStates} {
        while {[llength $symbols] > 0} {
            # TODO probably doesn't work correctly after all
            # unfollowed states are left in the states list <- no they aren't
            my OutputState $states $symbols
            set states [my ε-moves $states 2]
            set tuples [my MatchTransition $states $symbols]
            set states [lsort -unique [lmap tuple $tuples {lindex $tuple 2}]]
            set symbols [lrange $symbols 1 end]
        }
        return [my Accepting $acceptStates $states $symbols]
    }

}

oo::class create ::automaton::PDA {
    mixin ::automaton::Utils

    variable options transitions output out

    constructor args {
        my AssignArgs $args options transitions output out
    }

    method accept {states symbols stack acceptStates} {
        # must be recursive because of stack
        my OutputState $states $symbols $stack
        set states [my ε-moves $states 3 $stack]
        if {[llength $symbols] eq 0} {
            return [my Accepting $acceptStates $states $symbols $stack]
        }
        set tuples [my MatchTransition $states $symbols $stack]
        set symbols [lrange $symbols 1 end]
        set stack [lrange $stack 1 end]
        foreach tuple $tuples {
            if {[lindex $tuple end 0] eq "ε"} {
                set tuple [lrange $tuple 0 3]
            }
            set α [lassign $tuple - - - p]
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
