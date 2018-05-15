package require log

oo::class create Dump {
    variable dump
    method dump+ args {lappend dump $args}
    method dump {} {set dump}
    method reset args {set dump {} ; next {*}$args}
}

oo::class create Output {
    variable output
    method OutputCollect args {lappend output {*}$args}
    method output {} {set output}
    method reset args {set output {} ; next {*}$args}
}

# Q : the set of allowed states
# Σ : the "alphabet" (set of input symbols)
# Σε: the union (Σ ∪ ε)
# Γ : the "stack alphabet" (set of stack symbols)
# δ : the transition dictionary (Q × Σε × Γ) → (Q × Γ*)
# s : the initial state
# Z : the initial stack contents
# F : the set of accept states
# 
oo::class create PDA {
    mixin Dump Output

    variable tuple script state stack token slave

    constructor args {
        lassign $args tuple script
        dict set tuple Σε [linsert [dict get $tuple Σ] 0 {}]
        dict set tuple Γε [linsert [dict get $tuple Γ] 0 {}]
        my reset
    }

    method reset {} {
        set state [dict get $tuple s]
        set stack [dict get $tuple Z]
        set token {}
        catch {interp delete $slave}
        set slave [my InitSlave $script]
    }

    method InitSlave s {
        set i [interp create -safe]
        $i alias emit [self namespace]::my OutputCollect
        $i eval $s
        return $i
    }

    method show key {
        dict get $tuple $key
    }

    method stackop args {
        foreach arg $args {
            if {$arg ni [dict get $tuple Γ]} {
                return -code error [format {Illegal stack token "%s"} $arg]
            }
        }
        set Z [dict get $tuple Z]
        if {[lindex $stack 0] eq $Z} {
            set stack [linsert $args end $Z]
        } else {
            set stack [lreplace $stack 0 0 {*}$args]
        }
    }

    method addTransition {qp ap Xp t} {
        log::log d [info level 0]
        set d [dict get $tuple δ]
        set keys0 [lmap v [dict get $tuple Q] {if {[string match $qp $v]} {set v} continue}]
        set keys1 [lmap v [dict get $tuple Σε] {if {[string match $ap $v]} {set v} continue}]
        set keys2 [lmap v [dict get $tuple Γ] {if {[string match $Xp $v]} {set v} continue}]
        foreach k0 $keys0 {
            foreach k1 $keys1 {
                foreach k2 $keys2 {
                    dict set d $k0 $k1 $k2 $t
                }
            }
        }
        log::log d \$d=$d
        dict set tuple δ $d
    }

    method δ {q a X} {
        if {[dict exists [dict get $tuple δ] $q $a $X]} {
            lassign [dict get [dict get $tuple δ] $q $a $X] state γ action
            if {$state ni [dict get $tuple Q]} {
                return -code error [format {illegal state "%s" reached in transition (%s,%s,%s)} $q $a $X]
            }
            if {${γ} ne "-"} {
                my stackop {*}${γ}
            }
            set actionResult [$slave eval $action]
            my dump+ $q $a $X -> $state ${γ} $actionResult $stack
        } else {
            return -code error [format {Illegal transition (%s,%s,%s)} $q $a $X]
        }
    }

    method run tokens {
        for {set i 0} {$i <= [llength $tokens]} {incr i} {
            set token [lindex $tokens $i]
            $slave eval [list set token $token]
            lassign $token a
            if {$a ni [dict get $tuple Σε]} {
                my dump+ [format {Illegal input token "%s" at index #%d} $token $i]
                break
            }
            try {
                my δ $state $a [lindex $stack 0]
            } on error msg {
                my dump+ Error:\ $msg
                break
            }
        }
        set result [expr {$state in [dict get $tuple F]}]
        my dump+ $result
        return $result
    }
}
