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
    variable slave output aliases
    method Reset args {
        catch {interp delete $slave}
        set slave [my InitSlave]
        set output {}
        if {[info exists aliases]} {
            foreach alias $aliases {
                $slave alias {*}$alias
            }
        }
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
    method alias args {
        lappend aliases $args
    }
    method OutputCollect args {lappend output {*}$args}
    method output {} {set output}
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
        my Ensure {subset($F, $Q)} {illegal accepting state(s) (%s)} [join [expr {diff($F, $Q)}] {, }]
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
        my Assert {[llength $keys0] > 0} {no matching keys for "%s"} $qp
        my Assert {[llength $keys1] > 0} {no matching keys for "%s"} $ap
        my Assert {[llength $keys2] > 0} {no matching keys for "%s"} $Xp
        foreach k0 $keys0 {
            foreach k1 $keys1 {
                foreach k2 $keys2 {
                    dict set tuple δ [my FormatTransition $k0 $k1 $k2] $t
                }
            }
        }
    }

    method NewState trans {
        dict with tuple {}
        return []
    }

    method read {tokens args} {
        my Reset
        my Eval {*}$args
        dict with tuple {set state $s}
        foreach token [linsert $tokens end ε] {
            lassign $token a
            my Eval [list vars $token]
            set trans [my FormatTransition $state $a [my StackTop]]
            if {![dict exists ${δ} $trans]} {
                my Log error [format {illegal transition %s} $trans]
                return 0
            }
            lassign [dict get ${δ} $trans] state γ action
            my StackAdjust {*}${γ}
            my Eval $action
            my Note [list $trans -> $state [my GetStack]]
        }
        return [expr {$state in $F}]
    }
}
