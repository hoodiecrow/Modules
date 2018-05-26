set collectedOutput {}

proc emit args {
    if {[lindex $args 0] eq "-clear"} {
        set ::collectedOutput {}
    } else {
        if {[llength $args] > 0} {
            lappend ::collectedOutput {*}$args
        } else {
            set ::collectedOutput
        }
    }
}

proc reset {} {
    set ::collectedOutput {}
    __RESET
}
