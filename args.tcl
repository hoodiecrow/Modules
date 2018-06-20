proc foo args {
    array set options {-bargle {} -bazout vampires -quxwoo 0}
    while {[llength $args]} {
        switch -glob -- [lindex $args 0] {
            -bar*   {set args [lassign $args - options(-bargle)]}
            -baz*   {set args [lassign $args - options(-bazout)]}
            -qux*   {set options(-quxwoo) 1 ; set args [lrange $args 1 end]}
            --      {set args [lrange $args 1 end] ; break}
            -*      {error "unknown option [lindex $args 0]"}
            default break
        }
    }
}

    method AssignArgs {arglist optVarName args} {
        upvar 1 $optVarName optvar
        foreach arg $args {
            upvar 1 $arg $arg
        }
        while {[string match -* [lindex $arglist 0]]} {
            if {[lindex $arglist 0] eq "--"} {
                set arglist [lrange $arglist 1 end]
                break
            }
            set arglist [lassign $arglist opt optvar($opt)]
        }
        return [lassign $arglist {*}$args]
    }
