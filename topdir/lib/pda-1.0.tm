package require local::logger
package require struct::stack

oo::class create Stack {
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

oo::class create PDASlave {
    # Delegates everything except a reset method and a fields method to a safe
    # interpreter. The last argument, if any are given, is a script that will
    # be run when the reset method is called. Other arguments will be used as
    # file names to be sourced in the global scope of the interpreter during
    # instance creation.
    variable slave
    constructor args {
        set slave [interp create -safe]
        $slave expose source
        foreach arg [lrange $args 0 end-1] {
            $slave eval [list uplevel #0 [list source -encoding utf-8 $arg]]
        }
        $slave hide source
        oo::objdefine [self] method reset {} [list $slave eval [lindex $args end]]
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
        if {$s ni $Q} {
            return -code error [format {illegal start state "%s"} $s]
        }
        if {$Z ni ${Γ}} {
            return -code error [format {illegal stack symbol "%s"} $Z]
        }
        if {!subset($F, $Q)} {
            return -code error [format {illegal accepting state(s) (%s)} [join [expr {diff($F, $Q)}] {, }]]
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
        log::log d [info level 0] 
        # TODO move into slave
        my LogReset
        dict with tuple {set state $s}
        set stack [Stack new $Z]
        catch { $slave reset }
        foreach token [linsert $tokens end ε] {
            catch { $slave fields $token }
            set trans ($state,[lindex $token 0],[$stack peek])
            if {[dict exists ${δ} $trans]} {
                lassign [dict get ${δ} $trans] state γ action
                $stack adjust {*}${γ}
                catch { $slave eval $action }
                # TODO move into slave
                my Note [list $trans -> $state [$stack get]]
            } else {
                # TODO move into slave
                my Log error [format {illegal transition %s} $trans]
                return 0
            }
        }
        $stack destroy
        return [expr {$state in $F}]
    }
}
