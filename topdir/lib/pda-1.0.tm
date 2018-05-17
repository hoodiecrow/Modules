package require log

oo::class create Log {
    method Reset args {log::lvChannel error stdout ; next {*}$args}
    forward Log ::log::log
    forward Warn ::log::log warning
    forward Info ::log::log info
    method Error msg {
        log::log d [info level 0] 
        log::log error $msg
        return -code error [format {Error: %s} $msg]
    }
    method Assert {cond {msg {}} args} {
        if {![uplevel 1 [list expr $cond]]} {
            set prefix [lindex [info level -1] 1]
            if {$msg eq {}} {
                my Error [format {%s: assertion failed: %s} $prefix $cond]
            } else {
                my Error [format {%s: %s} $prefix [format $msg {*}$args]]
            }
        }
    }
    method Ensure {cond msg args} {
        log::log d [info level 0] 
        if {![uplevel 1 [list expr $cond]]} {
            my Error [format $msg {*}$args]
        }
    }
}

oo::class create Dump {
    variable dump
    method Reset args {set dump {} ; next {*}$args}
    method dump {} {set dump}
    method Dump args {lappend dump $args}
    method Error msg {
        my Dump $msg
        return -code error [format {Error: %s} $msg]
    }
    method Assert {cond {msg {}} args} {
        if {![uplevel 1 [list expr $cond]]} {
            set prefix [lindex [info level -1] 1]
            if {$msg eq {}} {
                my Error [format {%s: assertion failed: %s} $prefix $cond]
            } else {
                my Error [format {%s: %s} $prefix [format $msg {*}$args]]
            }
        }
    }
    method Ensure {cond msg args} {
        if {![uplevel 1 [list expr $cond]]} {
            my Error [format $msg {*}$args]
        }
    }
}

oo::class create Stack {
    variable stack tuple
    method Reset args {set stack [dict get $tuple Z] ; next {*}$args}
    method stackop args {
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
    mixin Stack

    variable tuple

    constructor args {
        lassign $args tuple
        if {![dict exists $tuple δ]} {
            dict set tuple δ {}
        }
    }

    foreach m {Eval Dump Error Assert Reset} {
        forward $m list
    }

    method Ensure {cond msg args} {
        if {![uplevel 1 [list expr $cond]]} {
            return -code error [format $msg {*}$args]
        }
    }

    method show key {
        dict get $tuple $key
    }

    method addTransition {qp ap Xp t} {
        log::log d [info level 0]
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
                    dict set tuple δ $k0 $k1 $k2 $t
                }
            }
        }
    }

    method δ {q a X} {
        log::log d [info level 0]
        set transition [format {(%s,%s,%s)} $q $a $X]
        set transmat [dict get $tuple δ]
        my Ensure {[dict exists $transmat $q $a $X]} {illegal transition %s} $transition
        lassign [dict get $transmat $q $a $X] state γ action
        my Ensure {$state in [dict get $tuple Q]} {illegal state "%s" reached in transition %s} $state $transition
        # TODO validate γ
        my stackop {*}${γ}
        my Eval $action
        my Dump $transition -> $state [my GetStack]
        return $state
    }

    method Check {} {
        dict with tuple {}
        my Assert {$s in $Q} {start state "%s" not in states set (%s)} $s [join $Q {, }]
        my Assert {$Z in ${Γ}} {initial stack symbol "%s" not in stack symbol set (%s)} $Z [join ${Γ} {, }]
        set fs [lmap f $F {if {$f in $Q} {set f} continue}]
        my Assert {[llength $fs] > 0} \
            {accepting state%s (%s) not in states set (%s)} \
            [expr {[llength $fs] > 1 ? "s" : ""}] \
            [join $f {, }] \
            [join $Q {, }]
    }

    method iterate tokens {
        set alpha [linsert [dict get $tuple Σ] end ε]
        dict with tuple {set state $s}
        foreach token [linsert $tokens end ε] {
            lassign $token a
            my Ensure {$a in $alpha} {input symbol "%s" not in alphabet (%s)} $a [join $alpha {, }]
            my Eval [list vars $token]
            try {
                my δ $state $a [my StackTop]
            } on ok state {
                # no op
            } on error msg {
                return 0
            }
        }
        return [expr {$state in [dict get $tuple F]}]
    }

    method read {tokens args} {
        my Reset
        my Eval {*}$args
        try {
            my Check
        } on ok {} {
            set result [my iterate $tokens]
        } on error {} {
            set result 0
        }
        return $result
    }
}
