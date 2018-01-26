
oo::object create optionHandler

oo::objdefine optionHandler {
    variable varName data

    method name name {
        set varName $name
        if {[info exists $varName]} {
            upvar 0 $varName options
            foreach opt [lsort [array names options]] {
                my option $opt value $options($opt)
            }
        }
    }

    method option {opt args} {
        # keys: value flag doc proc
        # Set the list of additional valid option names (without defaults: they
        # are only present in the finished options array if they occur on the
        # command line).
        # Set the names of options that are flags, i.e. value is 1 or 0, and
        # they don't consume any value from the command line.
        # Set documentation strings for options. Arguments must be an
        # even-sized sequence of option names and documentation strings.
        # Set a dict of option names and command prefixes with which to
        # pre-process argument values. Members with invalid option names are
        # allowed.
        dict set data $opt {}
        foreach {key val} $args {
            dict set data $opt $key $val
            if {$key eq "flag" && $val && ![dict exists $data $opt value]} {
                dict set data $opt value 0
            }
        }
    }

    method DoProcessing opt {
        log::logMsg [info level 0]
        # This method is only called when the option has a value.
        if no {
        set val [dict get $data $opt value]
        log::logMsg \$val=$val
        if {[dict exists $data $opt proc]} {
            set val [{*}[dict get $data $opt proc] $val]
        }
        log::logMsg \$val=$val
        } else {
        dict with data $opt {
            if {[info exists proc]} {
                set value [{*}$proc $value]
            }
        }
        }
        return $value
    }

    method handle {script args} {
        # Called with the command line to handle options for.
        # Option names can be abbreviated.  When an option value is found, it
        # is simply assigned to that member in the options array unless there
        # exists a corresponding member in 'processors', in which case the
        # member in the options array is assigned the value of evaluating that
        # command prefix with the option value appended. The -- delimiter (or
        # the first non-option argument) ends command-line processing. The
        # remaining arguments are returned, including the -- delimiter if it
        # occurs.  An error is raised if an unrecognized option is found.
        unset -nocomplain varName data
        namespace eval [self namespace] $script
        if {![info exists varName]} {
            return -code error [mc {no array name given}]
        }
        upvar 0 $varName options
        # Traverse the command line and handle options.
        for {set i 0} {$i < [llength $args]} {incr i} {
            set word [lindex $args $i]
            log::logMsg \$word=$word
            if {$word eq "--"} {
                return [lrange $args $i+1 end]
            } elseif {![string match -* $word]} {
                return [lrange $args $i end]
            }
            # Expand abbreviated option names and report bad option names.
            set opt [::tcl::prefix match -message option [dict keys $data] $word]
            log::logMsg \$opt=$opt
            if {[dict exists $data $opt flag]} {
                dict set data $opt value 1
            } else {
                dict set data $opt value [lindex $args [incr i]]
            }
            log::logMsg val=[dict get $data $opt]
            set options($opt) [my DoProcessing $opt]
        }
    }
}
