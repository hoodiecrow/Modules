package require local::logger

oo::class create PDAStack {
    variable stack start symbols
    method InitStack args {
        lassign $args start symbols
    }
    method Reset args {set stack $start ; next {*}$args}
    method AdjustStack args {
        if {[llength $args] eq 1 && [lindex $args 0] eq "-"} {
            return
        }
        foreach arg $args {
            my Ensure {$arg in $symbols} {illegal stack token "%s"} $arg
        }
        if {[my StackTop] eq $start} {
            set stack [linsert $args end $start]
        } else {
            set stack [lreplace $stack 0 0 {*}$args]
        }
    }
    method StackTop {} {lindex $stack 0}
    method GetStack {} {set stack}
}

oo::class create PDASlave {
    variable slave script output
    constructor args {
        set slave [interp create -safe]
        $slave alias emit [self namespace]::my OutputCollect
        $slave alias vars [self namespace]::my SlaveVars
        set script {}
        my reset
        lassign $args script
    }
    destructor {
        interp delete $slave
    }
    method reset {} {
        log::log d [info level 0] 
        set output {}
        $slave eval $script
    }
    method SlaveVars vals {
        $slave eval {unset -nocomplain {*}[info vars {[1-9]*}]}
        $slave eval [list set 0 $vals]
        for {set i 1} {$i <= [llength $vals]} {incr i} {
            $slave eval [list set $i [lindex $vals $i-1]]
        }
    }
    method OutputCollect args {
        log::log d [info level 0] 
        lappend output {*}$args
    }
    method output {} {
        log::log d [info level 0] 
        set output
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
    mixin NoLog PDAStack

    variable tuple slave

    constructor args {
        lassign $args tuple slave
        if {![dict exists $tuple δ]} {
            dict set tuple δ {}
        }
        dict with tuple {}
        my Ensure {$s in $Q} {illegal start state "%s"} $s
        my Ensure {$Z in ${Γ}} {illegal stack symbol "%s"} $Z
        my Ensure {subset($F, $Q)} {illegal accepting state(s) (%s)} [join [expr {diff($F, $Q)}] {, }]
        my InitStack $Z ${Γ}
        if no {
        oo::objdefine [self] forward output $slave output
        }
    }

    method Reset args {
        catch { $slave reset }
    }

    method set {key val} {
        dict set tuple $key $val
    }

    method get key {
        dict get $tuple $key
    }

    method output {} {
        log::log d [info level 0] 
        $slave output
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

    method read {tokens args} {
        my Reset
        if no {
        catch { $slave eval {*}$args }
        }
        catch { $slave reset }
        dict with tuple {set state $s}
        foreach token [linsert $tokens end ε] {
            lassign $token a
            catch { $slave eval [list vars $token] }
            set trans ($state,$a,[my StackTop])
            if {![dict exists ${δ} $trans]} {
                my Log error [format {illegal transition %s} $trans]
                return 0
            }
            lassign [dict get ${δ} $trans] state γ action
            my AdjustStack {*}${γ}
            catch { $slave eval $action }
            my Note [list $trans -> $state [my GetStack]]
        }
        return [expr {$state in $F}]
    }
}
