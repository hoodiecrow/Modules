
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
        }
        set args [my SetOptions {*}$args]
        set values [my SetValues $options(-values)]
        set head 0
        set data {}
        foreach arg $args {
            my Update $arg
            incr head
        }
        my ResetHead
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
            set args [lassign $args opt val]
            set options($opt) $val
        }
        if {[info exists options(-default)] && [llength $args] eq 0} {
            lappend args $options(-default)
        }
        return $args
    }

    method SetValues vals {
        set vals [lmap val $vals {lindex $val 0}]
        if {[llength $vals] > 0} {
            lappend vals $options(-blank)
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
                    [format {illegal value "%s" not in "%s"} \
                        $val \
                        [join [lmap value $options(-values) {lindex $value 0}] {, }]]
        }
    }

    method Update val {
        my CheckValues $val
        lset data $head $val
    }

    method Blank {} {
        lset data $head $options(-blank)
    }

    method Data {} {
        set data
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

    method AtLeftEdge {} {
        if {$options(-leftbound)} {
            expr {$head < 1}
        } else {
            return 0
        }
    }

    method Left {} {
        if {![my AtLeftEdge]} {
            incr head -1
        }
        return
    }

    method AtRightEdge {} {
        if {$options(-rightbound) >= 0} {
            expr {$head >= $options(-rightbound) - 1}
        } else {
            return 0
        }
    }

    method Right {} {
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

    forward read my Read
    forward write my Update
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
    export L R

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

    method read {} {
        set val [my Read]
        if {[my AtRightEdge]} {
            set hasTokens 0
        }
        my Right
        return $val
    }

}
