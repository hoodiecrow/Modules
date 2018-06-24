package require struct::graph
package require struct::queue
package require struct::stack
package require Tclx

interp alias {} lintersect {} intersect
interp alias {} ltail {} apply {list {lrange $list 1 end}}

# https://en.wikipedia.org/wiki/Finite-state_transducer

# --- FSA: finite state acceptor/automaton

catch {BuildGraph destroy}
oo::class create BuildGraph {
    variable graph
    method InsertNodes transitions {
        foreach {from - to} $transitions {
            lappend states $from $to
        }
        $graph node insert {*}[lsort -unique $states]
    }
    method InsertArcs transitions {
        foreach {from edge to} $transitions {
            set arc [$graph arc insert $from $to]
            lassign [split $edge /] input output
            $graph arc set $arc input $input
            $graph arc set $arc output $output
        }
    }
    method BuildGraph transitions {
        set graph [::struct::graph]
        my InsertNodes $transitions
        my InsertArcs $transitions
        return $graph
    }
}

catch {FSA destroy}
oo::class create FSA {
    mixin BuildGraph

    variable g node

    constructor args {
        lassign $args start accept transitions
        set g [my BuildGraph $transitions]
        $g node set $accept accept 1
        set node $start
    }

    destructor {
        $g destroy
    }

    method Move symbol {
        set node [$g arc target [$g arcs -key input -value $symbol -out $node]]
    }

    method accept code {
        lassign [split $code /] input output
        while {[$input size] > 0} {
            my Move [$input get]
        }
        return [$g node get $node accept]
    }

}


# --- FST: finite state transducer

catch {FST destroy}
oo::class create FST {
    mixin BuildGraph

    variable g node

    constructor args {
        lassign $args start accept transitions
        set g [my BuildGraph $transitions]
        $g node set $accept accept 1
        set node $start
    }

    destructor {
        $g destroy
    }

    method Move symbol {
        set arc [$g arcs -key input -value $symbol -out $node]
        set node [$g arc target $arc]
        $g arc get $arc output
    }

    method accept code {
        lassign [split $code /] input output
        while {[$input size] > 0} {
            $output put [my Move [$input get]]
        }
        return [$g node get $node accept]
    }

}

catch {StackAdapter destroy}
oo::class create StackAdapter {
    variable s

    constructor args {
        set s [::struct::stack]
        if {[llength $args] > 0} {
            lassign $args source
            $s push {*}[lreverse [$source get]]
        }
        oo::objdefine [self] forward get $s pop
        oo::objdefine [self] forward put $s push
    }

    destructor {
        $s destroy
    }

}

catch {PDA destroy}
oo::class create PDA {
    mixin BuildGraph

    variable g accepting transitions
    constructor args {
        log::log d [info level 0] 
        lassign $args accepting transitions
        set g [my BuildGraph $transitions]
    }

    destructor {
        $g destroy
    }

    method ε-moves {state stack} {
        set arcs [$g arcs -key input -value ε,[lindex $stack 0] -out $state]
        set s [lmap arc $arcs {
            $g arc target $arc
        }]
        log::log d "ε: \$arcs=$arcs, \$s=$s"
        return [linsert [lsort -unique $s] 0 $state]
    }

    method MooreEnter {states {cmd list}} {
        # TODO Moore hook / entry
        foreach state $states {
            {*}$cmd $state
        }
    }

    method MooreExit {arcs {cmd list}} {
        # TODO Moore exit
        foreach arc $arcs {
            {*}$cmd [$g arc source $arc]
        }
    }

    method Mealy {arcs {cmd list}} {
        # TODO Mealy state x inputSymbol x stackSymbol
        foreach arc $arcs {
            {*}$cmd [$g arc target $arc] {*}[split [$g arc get $arc input] ,]
        }
    }

    method _Run {states symbols stack} {
        my MooreEnter $states
        if {[llength $symbols] <= 0} {
            return [expr {[llength [lintersect $states $accepting]] > 0}]
        } else {
            set symbols [lassign $symbols inputSymbol]
            set stack [lassign $stack stackSymbol]
            set arcs [$g arcs -key input -value $inputSymbol,$stackSymbol -out {*}$states]
            my Mealy $arcs
            my MooreExit $arcs ;# {apply {args {puts $args}}}
            set result [lmap arc $arcs {
                set output [$g arc get $arc output]
                if {$output eq "ε"} {
                    set output {}
                }
                my accept [$g arc target $arc] $symbols [concat $output $stack]
            }]
            return [expr {1 in $result}]
        }
    }

    method _accept {start symbols stack} {
        log::log d [info level 0] 
        my Run [lsort -unique [my ε-moves $start $stack]] $symbols $stack
    }

    method accept {start symbols stack} {
        log::log d [info level 0] 
        set states [lsort -unique [my ε-moves $start $stack]]
        my MooreEnter $states
        if {[llength $symbols] <= 0} {
            return [expr {[llength [lintersect $states $accepting]] > 0}]
        } else {
            set symbols [lassign $symbols inputSymbol]
            set stack [lassign $stack stackSymbol]
            set arcs [$g arcs -key input -value $inputSymbol,$stackSymbol -out {*}$states]
            my Mealy $arcs
            my MooreExit $arcs ;# {apply {args {puts $args}}}
            set result [lmap arc $arcs {
                set output [$g arc get $arc output]
                my accept [$g arc target $arc] $symbols [concat $output $stack]
            }]
            return [expr {1 in $result}]
        }
    }

}

FSA create M s0 s0 {
    s0 1 s0
    s0 0 s1
    s1 0 s0
    s1 1 s1
}

set q [::struct::queue]
$q put {*}[split 0010110 {}]
puts "FSA: [M accept $q]"

FST create T s0 s0 {
    s0 1/A s0
    s0 0/Z s1
    s1 0/Z s0
    s1 1/A s1
}
$q destroy

set qi [::struct::queue]
set qo [::struct::queue]
$qi put {*}[split 0010110 {}]
puts "FST: [T accept $qi/$qo]"
while {[$qo size] > 0} {
    puts -nonewline "[$qo get] "
}
puts {}
$qi destroy
$qo destroy

package require log
::log::lvSuppressLE i 0
PDA create P r {
    p "0,Z/A Z" p
    p "0,A/A A" p
    p ε,Z/Z     q
    p ε,A/A     q
    q 1,A/      q
    q ε,Z/Z     r
}

# "a,b/b'" -> get one symbol each from A and B (compare to a,b), put some output (b') on B
# "a/b'"   -> get one symbol from A (compare to a), put some output (b') on B
# "a,b"    -> get one symbol each from A and B (compare to a,b)
# "a"      -> get one symbol from A (compare to a)

puts "PDA: [P accept p [split 000111 {}] [list Z]]"


return



if no {
# PDA
    oo::class create _PDA {
        variable g node

        constructor args {
            lassign $args start accept transitions
            set g [::struct::graph]
            foreach {from edge to} $transitions {
                foreach node [list $from $to] {
                    if {![$g node exists $node]} {
                        $g node insert $node
                        $g node set $node accept 0
                    }
                }
                lassign [split $edge /] input output
                set arc [$g arc insert $from $to]
                $g arc set $arc input $input
                $g arc set $arc output $output
            }
            $g node set $accept accept 1
            set node $start
        }

        destructor {
            $g destroy
        }

        method Moves {orig label} {
            $g arcs -key input -value $label -out $orig
        }

        method Move label {
            set arc [$g arcs -key input -value $label -out $node]
            set node [$g arc target $arc]
            $g arc get $arc output
        }

        method accept args {
            if {[llength $args] < 2} {
                set start $node
                lassign $args code
            } else {
                lassign $args start code
            }
            lassign [split $code /] input output
            lassign [split $input ,] inp0 inp1
            set res {}
            if {[$inp0 size] <= 0} {
                return [$g node get $node accept]
            } else {
                set i0 [$inp0 get]
                set i1 [$inp1 get]
                set moves [my Moves ε,$i1]
                set nodes [lmap move $moves {$g arc target $move}]

                lappend moves {*}[my Moves $i0,$i1]
                set res [foreach move $moves {
                    set o [StackAdapter new $output]
                    $o put [$g arc get $move output]
                    my Accept [$g arc target $move] $inp0,$o/$o
                }]
                return [expr {1 in $res}]
            }
        }

    }
}

proc ::tcl::mathfunc::intersectp {a b} {
    foreach x $a {
        if {$x in $b} {
            return 1
        }
    }
    return 0
}

