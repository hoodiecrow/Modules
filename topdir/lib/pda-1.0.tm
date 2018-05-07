package require log

catch {PDA destroy}
# Q : the set of allowed states
# Σ : the "alphabet" (set of input symbols)
# Γ : the "stack alphabet" (set of stack symbols)
# δ : the transition dictionary (Q × (Σ U ε) × Γ) → (Q × Γ*)
# s : the initial state
# Z : the initial stack contents
# F : the set of accept states
oo::class create PDA {
    variable Q Σ Γ δ s Z F state stack token
    constructor args {
        lassign $args Q Σ Γ δ s Z F
        my reset
    }

    method reset {} {
        set state $s
        set stack $Z
        set token {}
    }

    method stackop args {
        if {[lindex $stack 0] eq $Z} {
            set stack [linsert $args end $Z]
        } else {
            set stack [lreplace $stack 0 0 {*}$args]
        }
    }

    method δ {q a X} {
        if {[dict exists ${δ} $q $a $X]} {
            lassign [dict get ${δ} $q $a $X] state γ action
            my stackop {*}${γ}
            my eval $action
            log::log d [list $q $a $X -> $state ${γ} $action $stack]
        } else {
            return -code error [format {Illegal transition (%s,%s,%s)} $q $a $X]
        }
    }

    method run tokens {
        for {set i 0} {$i <= [llength $tokens]} {incr i} {
            set token [lindex $tokens $i]
            lassign $token a
            if {$a ni [linsert ${Σ} end {}]} {
                return -code error [format {Illegal input token "%s"} $token]
            }
            my δ $state $a [lindex $stack 0]
        }
        expr {$state in $F}
    }
}
