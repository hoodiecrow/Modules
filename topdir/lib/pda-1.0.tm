package require local::logger

oo::class create Stack {
    variable stack tuple
    method Reset args {set stack [dict get $tuple Z] ; next {*}$args}
    method StackAdjust args {
        if {[llength $args] eq 1 && [lindex $args 0] eq "-"} {
            return
        }
        foreach arg $args {
            my Ensure {$arg in [dict get $tuple Γ]} {illegal stack token "%s"} $arg
        }
        set Z [dict get $tuple Z]
        if {[my StackTop] eq $Z} {
            set stack [linsert $args end $Z]
        } else {
            set stack [lreplace $stack 0 0 {*}$args]
        }
    }
    method StackTop {} {lindex $stack 0}
    method GetStack {} {set stack}
}

oo::class create Slave {
    variable slave output
    method Reset args {
        catch {interp delete $slave}
        set slave [my InitSlave]
        set output {}
        next {*}$args
    }
    method InitSlave {} {
        set i [interp create -safe]
        $i alias emit [self namespace]::my OutputCollect
        $i alias vars [self namespace]::my SlaveVars
        return $i
    }
    method SlaveVars vals {
        $slave eval {unset -nocomplain {*}[info vars {[1-9]*}]}
        $slave eval [list set 0 $vals]
        for {set i 1} {$i <= [llength $vals]} {incr i} {
            $slave eval [list set $i [lindex $vals $i-1]]
        }
    }
    method Eval args {
        if {[llength $args] > 0} {
            $slave eval {*}$args
        }
    }
    method OutputCollect args {lappend output {*}$args}
    method output {} {set output}
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
oo::class create PDA {
    mixin NoLog Stack

    variable tuple

    constructor args {
        lassign $args tuple
        if {![dict exists $tuple δ]} {
            dict set tuple δ {}
        }
        my Check
    }

    forward Reset list
    forward Eval list

    method Check {} {
        dict with tuple {}
        my Ensure {$s in $Q} {illegal start state "%s"} $s
        my Ensure {$Z in ${Γ}} {illegal stack symbol "%s"} $Z
        set fs [lmap f $F {if {$f in $Q} {set f} continue}]
        my Ensure {[llength $fs] > 1} {illegal accepting states (%s)} [join $fs {, }]
        my Ensure {[llength $fs] > 0} {illegal accepting state "%s"} $f
    }

    method FormatTransition {q a X} {
        format {(%s,%s,%s)} $q $a $X
    }

    method addTransition {qp ap Xp t} {
        dict with tuple {
            set keys0 [lsearch -glob -all -inline $Q $qp]
            set keys1 [lsearch -glob -all -inline [linsert ${Σ} end ε] $ap]
            set keys2 [lsearch -glob -all -inline ${Γ} $Xp]
        }
        foreach keys [list $keys0 $keys1 $keys2] pattern [list $qp $ap $Xp] {
            my Assert {[llength $keys] > 0} {no matching keys for "%s"} $pattern
        }
        foreach k0 $keys0 {
            foreach k1 $keys1 {
                foreach k2 $keys2 {
                    dict set tuple δ [my FormatTransition $k0 $k1 $k2] $t
                }
            }
        }
    }

    method NewState trans {
        log::log d [info level 0]
        dict with tuple {}
        my Ensure {[dict exists ${δ} $trans]} {illegal transition %s} $trans
        lassign [dict get ${δ} $trans] state γ action
        my StackAdjust {*}${γ}
        my Eval $action
        return $state
    }

    method Iterate tokens {
        set alpha [linsert [dict get $tuple Σ] end ε]
        dict with tuple {set state $s}
        foreach token [linsert $tokens end ε] {
            lassign $token a
            my Ensure {$a in $alpha} {illegal input symbol "%s"} $a
            my Eval [list vars $token]
            set trans [my FormatTransition $state $a [my StackTop]]
            try {
                my NewState $trans
            } on ok state {
                my Note [list $trans -> $state [my GetStack]]
                my Ensure {$state in $Q} {illegal state "%s" reached in transition %s} $state $trans
            } on error {} {
                return 0
            }
        }
        return [expr {$state in $F}]
    }

    method read {tokens args} {
        my Reset
        my Eval {*}$args
        return [my Iterate $tokens]
    }
}
