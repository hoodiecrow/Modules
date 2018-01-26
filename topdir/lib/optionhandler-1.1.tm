# Clean up in case package is reloaded.
catch {AssertionHandler destroy}
catch {OptionHandler destroy}

oo::class create AssertionHandler {
    constructor args {
        if {[lindex $args 0] eq "-useassertions"} {
            set args [lrange $args 1 end]
            oo::objdefine [self] forward assert my Assert
        } else {
            oo::objdefine [self] method assert args {}
        }
        next {*}$args
    }

    method Assert expr {
        if {![uplevel 1 [list expr $expr]]} {
            return -code error "Assertion failed: $expr"
        }
    }

}

oo::class create OptionHandler {
    mixin AssertionHandler
    variable data table

    constructor args {
        set data {}
        foreach arg $args {
            my option {*}$arg
        }
    }

    method option {opt args} {
        my assert {[string match -* $opt]}
        dict set data $opt $args
        if {[dict exists $args flag] && [dict get $args flag]} {
            dict set data -no$opt flag 1
            if {![dict exists $args default]} {
                dict set data $opt default 0
            }
        }
        return
    }

    method extract {name args} {
        my assert {![info exists $name]}
        #my assert {[llength $args] > 0}
        array set $name {}
        my AddDefaults $name
        my ProcessCmdLine $name {*}$args
    }

    method usage {{prefix {}}} {
        # Create a usage message by concatenating a prefix and some rows of
        # option names and documentation strings.
        my assert {[info exists data]}
        dict for {opt val} $data {
            if {[dict exists $data $opt doc]} {
                lappend docs $opt\t[dict get $data $opt doc]
            }
        }
        return $prefix\nOptions:\n[join [lsort -dictionary $docs] \n]\n
    }

    method GetTable {} {
        my assert {[info exists data]}
        lsort -dictionary -unique [dict keys $data]
    }

    method ProcessCmdLine {name args} {
        set table [my GetTable]
        while {[llength $args] > 0} {
            set args [lassign $args word]
            log::logMsg \$word=$word,\ \$args=$args
            if {$word eq "--"} {
                # End traversing, return remaining words.
                return $args
            } elseif {$word eq "-help" || $word eq "-?"} {
                # End traversing, return usage message.
                return [my usage]
            } elseif {[string match -* $word]} {
                # Store one option and continue.
                if {[llength $table] > 0} {
                    # Expand abbreviated option names and report bad option names.
                    set opt [::tcl::prefix match -message option $table $word]
                } else {
                    set opt $word
                }
                if {[my IsFlag $opt]} {
                    if {[string match -no-* $opt]} {
                        set opt [string range $opt 3 end]
                        set val 0
                    } else {
                        set val 1
                    }
                } else {
                    set args [lassign $args val]
                }
                array set $name [list $opt $val]
            } else {
                # End traversing, return current and remaining words.
                return [list $word {*}$args]
            }
        }
        return
    }

    method AddDefaults name {
        my assert {[info exists $name]}
        my assert {[info exists data]}
        dict for {opt val} $data {
            if {[my IsFlag $opt] && [string match -no-* $opt]} {
                continue
            } elseif {[dict exists $data $opt default]} {
                array set $name [list $opt [dict get $data $opt default]]
            }
        }
    }

    method IsFlag opt {
        my assert {[info exists data]}
        expr {[dict exists $data $opt flag] && [dict get $data $opt flag]}
    }

}
