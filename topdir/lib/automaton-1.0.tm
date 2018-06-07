
namespace eval automaton {}

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
