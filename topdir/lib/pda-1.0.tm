package require local::logger
package require struct::stack

oo::class create Stack {
    variable stack
    constructor args {
        lassign $args start
        set stack [::struct::stack]
        oo::objdefine [self] forward push $stack push
        oo::objdefine [self] forward top $stack peek 1
        oo::objdefine [self] forward get $stack get
        my clear $start
    }
    destructor {
        $stack destroy
    }
    method clear start {
        $stack clear
        my push $start
    }
    method pop {} {
        if {[$stack size] > 1} {
            $stack pop
        }
    }
    method adjust args {
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
}

oo::class create PDASlave {
    variable slave
    constructor args {
        log::log d [info level 0] 
        set script [lindex $args end]
        set args [lrange $args 0 end-1]
        set slave [interp create -safe]
        $slave expose source
        foreach arg $args {
            if {[llength $arg] eq 1} {
                $slave eval [list uplevel #0 [list source -encoding utf-8 $arg]]
            } else {
                $slave eval $arg
            }
        }
        $slave hide source
        $slave eval [list proc __RESET {} [list uplevel #0 $script]]
        oo::objdefine [self] forward eval $slave eval
    }
    destructor {
        interp delete $slave
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
oo::class create PDA {
    mixin NoLog

    variable tuple

    constructor args {
        lassign $args tuple
        foreach key {Q Σ Γ δ s Z F} {
            if {![dict exists $tuple $key]} {
                dict set tuple $key {}
            }
        }
        dict with tuple {}
        my Ensure {$s in $Q} {illegal start state "%s"} $s
        my Ensure {$Z in ${Γ}} {illegal stack symbol "%s"} $Z
        my Ensure {subset($F, $Q)} {illegal accepting state(s) (%s)} [join [expr {diff($F, $Q)}] {, }]
        if no {
        my InitStack $Z ${Γ}
        }
    }

    method Reset args {
        if no {
    catch { $slave eval reset }
    }
    }

    method set {key val} {
        dict set tuple $key $val
    }

    method get key {
        dict get $tuple $key
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
                    dict set tuple δ ($k0,$k1,$k2) $t
                }
            }
        }
    }

    method read {tokens {slave {}}} {
        my Reset
        dict with tuple {set state $s}
        set stack [Stack new $Z]
        catch { $slave eval reset }
        foreach token [linsert $tokens end ε] {
            lassign $token a
            catch { $slave eval [list vars $token] }
            set trans ($state,$a,[$stack top])
            if {![dict exists ${δ} $trans]} {
                my Log error [format {illegal transition %s} $trans]
                return 0
            }
            lassign [dict get ${δ} $trans] state γ action
            $stack adjust {*}${γ}
            catch { $slave eval $action }
            my Note [list $trans -> $state [$stack get]]
        }
        $stack destroy
        return [expr {$state in $F}]
    }
}
