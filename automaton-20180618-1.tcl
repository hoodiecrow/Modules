package require struct::graph
package require struct::queue
package require struct::stack

# https://en.wikipedia.org/wiki/Finite-state_transducer

# --- FSA: finite state acceptor/automaton

catch {FSA destroy}
oo::class create FSA {
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
            $g arc set [$g arc insert $from $to] input $edge
        }
        $g node set $accept accept 1
        set node $start
    }

    destructor {
        $g destroy
    }

    method Move symbol {
        set node [g arc target [g arcs -key input -value $symbol -out $node]]
    }

    method accept code {
        lassign [split $code /] input output
        while {[$input size] > 0} {
            my Move [$input get]
        }
        return [g node get $node accept]
    }

}


# --- FST: finite state transducer

catch {FST destroy}
oo::class create FST {
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
        return [g node get $node accept]
    }

}

oo::class create StackAdapter {
    variable s

    constructor args {
        set s [::struct::stack {*}$args]
        oo::objdefine [self] forward get $s pop
        oo::objdefine [self] forward put $s push
    }

    destructor {
        $s destroy
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

# PDA
FST create P p r {
    p 0,Z/AZ p
    p 0,A/AA p
    p ε,Z/Z  q
    p ε,A/A  q
    q 1,A/ε  q
    q ε,Z/Z  r
}
$q destroy

set qi [::struct::queue]
set qo [StackAdapter new]
$qi put {*}[split 000111 {}]
puts "PDA: [P accept $qi/$qo]"
$qi destroy
$qo destroy
