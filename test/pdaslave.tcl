set collectedOutput {}

proc vars vals {
    uplevel #0 {unset -nocomplain {*}[info vars {[1-9]*}]}
    set ::0 $vals
    for {set i 1} {$i <= [llength $vals]} {incr i} {
        set ::$i [lindex $vals $i-1]
    }
}

proc emit args {
    if {[llength $args] > 0} {
        lappend ::collectedOutput {*}$args
    } else {
        set ::collectedOutput
    }
}

proc reset {} {
    set ::collectedOutput {}
    __RESET
}
