package require assertionhandler

oo::class create OptionHandler {
    mixin AssertionHandler
    variable data table varName

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
            dict set data [regsub {^(-{1,2})} $opt {\1no-}] flag 1
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
        set varName $name
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

    method defaultTo {opt1 opt2} {
        # TODO decide if should fail if opt2 not present
        if {![info exists $varName\($opt1)]} {
            if {[info exists $varName\($opt2)]} {
                set $varName\($opt1) [set $varName\($opt2)]
            }
        }
    }

    method expand {opt values} {
        set $varName\($opt) [::tcl::prefix match -message value $values [set $varName\($opt)]]
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
                    if {[regexp {^-{1,2}no-} $opt]} {
                        set opt [regsub {no-} $opt {}]
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
