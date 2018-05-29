package require struct::stack

namespace eval PDA {}

oo::class create ::PDA::Stack {
    # A stack that delegates to struct::stack except that it protects its
    # bottom element from popping and that it offers an 'adjust' method for
    # mutation.
    variable stack
    constructor args {
        lassign $args start
        set stack [::struct::stack]
        my push $start
    }
    destructor {
        $stack destroy
    }
    method pop {} {
        if {[$stack size] > 1} {
            $stack pop
        }
    }
    method adjust args {
        # If called with a single '-' as argument, leave stack unchanged. Else,
        # pop the stack and then push each argument.
        set nargs [llength $args]
        if {$nargs eq 0} {
            my pop
        } elseif {$nargs eq 1} {
            lassign $args arg
            if {$arg ne "-"} {
                my pop
                my push $arg
            }
        } else {
            my pop
            my push {*}[lreverse $args]
        }
    }
    method unknown args {
        $stack {*}$args
    }
}

oo::class create ::PDA::Slave {
    # Defines the methods reset, source, and fields; delegates everything else
    # to a safe interpreter. If given an argument, the reset method will
    # evaluate it in the interpreter as a script. The source method invokes
    # source on its arguments in the interpreter. The fields method is
    # documented below.
    variable slave
    constructor args {
        set slave [interp create -safe]
        log::log d [lindex $args 0]
        oo::objdefine [self] method reset {} [list $slave eval [lindex $args 0]]
        oo::objdefine [self] forward source $slave invokehidden source
    }
    destructor {
        interp delete $slave
    }
    method fields record {
        # Creates AWK-style field variables from an input list, with $0 being
        # the value of the whole list, and $1 etc being the values of the
        # items.
        $slave eval {unset -nocomplain {*}[info vars {[1-9]*}]}
        $slave eval [list set 0 $record]
        for {set i 1} {$i <= [llength $record]} {incr i} {
            $slave eval [list set $i [lindex $record $i-1]]
        }
    }
    method unknown args {
        $slave {*}$args
    }
}

proc ::tcl::mathfunc::subset {a b} {
    foreach item $a {
        if {$item ni $b} {
            return 0
        }
    }
    return 1
}

proc ::tcl::mathfunc::diff {a b} {
    return [lmap item $a {
        if {$item ni $b} {
            set item
        } else {
            continue
        }
    }]
}

# Q : the set of allowed states
# Σ : the "alphabet" (set of input symbols)
# Σε: the union (Σ ∪ { ε })
# Γ : the "stack alphabet" (set of stack symbols)
# δ : the transition dictionary (Q × Σε × Γ) → (Q × Γ*)
# s : the initial state
# Z : the initial stack contents
# F : the set of accept states
# 
oo::class create ::PDA::PDA {
    variable tuple state stack

    constructor args {
        lassign $args tuple
        foreach key {Q Σ Γ δ s Z F} {
            if {![dict exists $tuple $key]} {
                dict set tuple $key {}
            }
        }
        dict with tuple {}
        my Check {$s ni $Q} {illegal start state "%s"} $s
        my Check {$Z ni ${Γ}} {illegal stack symbol "%s"} $Z
        my Check {!subset($F, $Q)} {illegal accepting state(s) (%s)} [join [expr {diff($F, $Q)}] {, }]
    }

    method Check {cond args} {
        if [uplevel 1 [list expr $cond]] {
            return -code error -level 2 [format {*}$args]
        }
    }

    method set {key val} {
        dict set tuple $key $val
    }

    method get key {
        dict get $tuple $key
    }

    method addTransition {qp ap Xp value} {
        # Add new items to the transition dictionary. The first three arguments
        # are glob-style patterns for state labels, input symbols, and stack
        # symbols. The last argument is the transition value. It is an error if
        # any of the patters don't match any items in the respective alphabets.
        dict with tuple {
            set keys0 [lsearch -glob -all -inline $Q $qp]
            set keys1 [lsearch -glob -all -inline [linsert ${Σ} end ε] $ap]
            set keys2 [lsearch -glob -all -inline ${Γ} $Xp]
        }
        my Check {[llength $keys0] < 1} {no matching keys for "%s"} $qp
        my Check {[llength $keys1] < 1} {no matching keys for "%s"} $ap
        my Check {[llength $keys2] < 1} {no matching keys for "%s"} $Xp
        foreach k0 $keys0 {
            foreach k1 $keys1 {
                foreach k2 $keys2 {
                    dict set tuple δ ($k0,$k1,$k2) $value
                }
            }
        }
    }

    method Init {} {
        dict with tuple {
            set state $s
            set stack [::PDA::Stack new $Z]
        }
    }

    method Exec action {}

    method Each token {
        dict with tuple {}
        set current ($state,[lindex $token 0],[$stack peek])
        if {[dict exists ${δ} $current]} {
            lassign [dict get ${δ} $current] state γ action
            $stack adjust {*}${γ}
            my Exec $action
            return [list $current -> $state [$stack get]]
        } else {
            return -code error [list $current -> FAIL]
        }
    }

    method Done {} {
        $stack destroy
    }

    method read tokens {
        my Init
        set result {}
        try {
            foreach token [linsert $tokens end ε] {
                lappend result [my Each $token]
            }
        } on ok {} {
            concat [expr {$state in [my get F]}] [lappend result {}]
        } on error err {
            concat 0 [lappend result $err]
        } finally {
            my Done
        }
    }

}

oo::class create ::PDA::PDAWithSlave {
    variable tuple state slave

    method Init _s {
        next
        set slave $_s
        $slave reset
    }

    method Exec action {
        next $action
        $slave eval $action
    }

    method Each token {
        $slave fields $token
        try {
            next $token
        } on ok res {
            return $res
        } on error err {
            return -code error $err
        }
    }

    method read {tokens _s} {
        my Init $_s
        set result {}
        try {
            foreach token [linsert $tokens end ε] {
                lappend result [my Each $token]
            }
        } on ok {} {
            concat [expr {$state in [my get F]}] [lappend result {}]
        } on error err {
            concat 0 [lappend result $err]
        } finally {
            my Done
        }
    }

}
