oo::class create AssignArgs {
    variable arglist optVarName
    method assign args {
        set args [lassign $args cases arglist optVarName]
        foreach arg $args {
            upvar 1 $arg $arg
        }
        if {[llength $cases] > 0} {
            if {![dict exists $cases --]} {
                set cases [linsert $cases 0 -- {my QuitOptions}]
            }
            if {![dict exists $cases default]} {
                set cases [linsert $cases end default {my DefaultHandler}]
            }
            while {[llength $arglist] > 0 && [string match -* [lindex $arglist 0]]} {
                switch -glob [lindex $arglist 0] $cases
            }
        }
        set result [lassign $arglist {*}$args]
        return result
    }
    method QuitOptions {} {
        set arglist [lrange $arglist 1 end]
        return -level 1 -code break
    }
    method SetValOption {{name {}}} {
        set arglist [lassign $arglist opt]
        if {$name ne {}} {
            set opt $name
        }
        set arglist [lassign $arglist ${optVarName}($opt)]
    }
    method SetFlagOption {{name {}}} {
        set value 1
        set arglist [lassign $arglist opt]
        if {$name ne {}} {
            set opt $name
        }
        set options($opt) $value
    }
    method UnsetFlagOption {{name {}}} {
        set value 0
        set arglist [lassign $arglist opt]
        if {$name ne {}} {
            set opt $name
        }
        set options($opt) $value
    }
    method DefaultHandler {} {
        if {[string match -* [lindex $arglist 0]]} {
            return -code error [format {unknown option "%s"} [lindex $arglist 0]]
        } else {
            return -level 1 -code break
        }
    }
    method PrefixHandler args {
        set arglist [lassign $arglist str]
        set opt [::tcl::prefix match {*}$args $str]
        set arglist [lassign $arglist ${optVarName}($opt)]
    }
}
