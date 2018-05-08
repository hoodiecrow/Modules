package require log

# Q : the set of allowed states
# Σ : the "alphabet" (set of input symbols)
# Γ : the "stack alphabet" (set of stack symbols)
# δ : the transition dictionary (Q × (Σ U ε) × Γ) → (Q × Γ*)
# s : the initial state
# Z : the initial stack contents
# F : the set of accept states
oo::class create PDA {
    variable Q Σ Γ δ s Z F script state stack token int dump SS
    constructor args {
        lassign $args Q Σ Γ δ s Z F script
        my reset
        oo::objdefine [self] forward dump set [self namespace]::dump
    }

    if no {
    method SaveState {{s {}}} {
        if {$s eq {}} {
            lappend SS $state
        } else {
            lappend SS $s
        }
        return
    }

    method RestoreState {} {
        set state [lindex $SS end]
        set SS [lrange $SS 0 end-1]
        return state<-$state
    }
    }

    method reset {} {
        set state $s
        set stack $Z
        set token {}
        set SS {}
        catch {interp delete $int}
        set int [interp create -safe]
        $int eval {set output {}}
        $int eval {
            proc emit args {
                lappend ::output {*}$args
            }
        }
        if no {
        $int alias saveState {*}[namespace code my] SaveState
        $int alias restoreState {*}[namespace code my] RestoreState
        }
        $int eval $script
        set dump {}
    }

    method stackop args {
        foreach arg $args {
            if {$arg ni [concat {} ${Γ}]} {
                return -code error [format {Illegal stack token "%s"} $arg]
            }
        }
        if {[lindex $stack 0] eq $Z} {
            set stack [linsert $args end $Z]
        } else {
            set stack [lreplace $stack 0 0 {*}$args]
        }
    }

    method output {} {
        $int eval {set output}
    }

    method δ {q a X} {
        if {[dict exists ${δ} $q $a $X]} {
            lassign [dict get ${δ} $q $a $X] state γ action
            my stackop {*}${γ}
            set actionResult [$int eval $action]
            lappend dump [list $q $a $X -> $state ${γ} $actionResult $stack]
        } else {
            return -code error [format {Illegal transition (%s,%s,%s)} $q $a $X]
        }
    }

    method run tokens {
        for {set i 0} {$i <= [llength $tokens]} {incr i} {
            set token [lindex $tokens $i]
            $int eval [list set token $token]
            lassign $token a
            if {$a ni [linsert ${Σ} end {}]} {
                lappend dump [format {Illegal input token "%s" at index #%d} $token $i]
                break
            }
            try {
                my δ $state $a [lindex $stack 0]
            } on error msg {
                lappend dump Error:\ $msg
                break
            }
        }
        set result [expr {$state in $F}]
        lappend dump $result
        return $result
    }
}
