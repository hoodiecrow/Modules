package require struct::stack
package require automaton

namespace eval pda {}

oo::class create ::pda::Slave {
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
oo::class create ::pda::PDA {
    variable tuple state stack input

    constructor args {
        lassign $args tuple
        foreach key {Q Σ Γ δ s Z F} {
            if {![dict exists $tuple $key]} {
                dict set tuple $key {}
            }
        }
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

    method Init tokens {
        dict with tuple {
            set state [::automaton::State new -values $Q -accept $F $s]
            set stack [::automaton::Stack new -values ${Γ} $Z]
            oo::objdefine $stack method get {} { lreverse [my Data] }
            set input [::automaton::Input new -values ${Σ} -empty ε {*}$tokens]
        }
    }

    method Exec action {}

    method Each {{token {}}} {
        if {$token eq {}} {
            set token [$input read]
        }
        dict with tuple {}
        set current ([$state get],[lindex $token 0],[$stack top])
        if {[dict exists ${δ} $current]} {
            lassign [dict get ${δ} $current] _state γ action
            $state set $_state
            $stack adjust {*}${γ}
            my Exec $action
            return [list $current -> [$state get] [$stack get]]
        } else {
            return -code error [list $current -> FAIL]
        }
    }

    method Done {} {
        $stack destroy
        $input destroy
    }

    method read tokens {
        my Init $tokens
        set result {}
        try {
            while {[$input hasTokens]} {
                lappend result [my Each]
            }
        } on ok {} {
            concat [$state accept] [lappend result {}]
        } on error err {
            concat 0 [lappend result $err]
        } finally {
            my Done
        }
    }

}

oo::class create ::pda::PDAWithSlave {
    variable tuple state slave input

    method Init {tokens _s} {
        next $tokens
        set slave $_s
        $slave reset
    }

    method Exec action {
        next $action
        $slave eval $action
    }

    method Each {{token {}}} {
        if {$token eq {}} {
            set token [$input read]
        }
        $slave fields $token
        try {
            next $token
        } on ok res {
            return $res
        } on error err {
            return -code error $err
        }
    }

    method Done {} {
        $input destroy
    }

    method read {tokens _s} {
        my Init $tokens $_s
        set result {}
        try {
            while {[$input hasTokens]} {
                lappend result [my Each]
            }
        } on ok {} {
            concat [$state get] [lappend result {}]
        } on error err {
            concat 0 [lappend result $err]
        } finally {
            my Done
        }
    }

}
