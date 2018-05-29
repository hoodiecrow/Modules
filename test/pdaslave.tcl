namespace eval ::EMIT {
    variable output {}
    namespace export emit
}

proc ::EMIT::emit args {
    # Basic routine to handle output. If the first argument is '-clear', the
    # output list is cleared. Otherwise, the list of arguments is appended to
    # it (meaning that if no arguments are given, the output list is unchanged.
    # The output list is returned.
    variable output
    if {[lindex $args 0] eq "-clear"} {
        set output {}
    } else {
        lappend output {*}$args
    }
}

namespace import ::EMIT::emit
