
oo::object create conf
oo::objdefine conf {
    variable dir
    method setdir {} {set dir [file dirname [info script]]}
    method msgcat args {
        if {![namespace exists ::starkit] || ![info exists starkit::topdir]} {
            namespace eval ::starkit [list set topdir [file dirname $dir]]
        }
        if {[catch {package present msgcat}]} {
            interp alias {} ::mc {} format
        } else {
            if {[namespace exists [lindex $args 0]]} {
                set args [lassign $args ns]
            } else {
                set ns [uplevel 1 [list namespace current]]
            }
            if {[llength $args] < 1} {
                set args {. ..}
            }
            proc ::mc args [format {namespace eval %s [list ::msgcat::mc {*}$args]} $ns]
            namespace eval $ns [format {
                ::msgcat::mclocale sv
                foreach dir {%s} {
                    ::msgcat::mcload [file normalize [file join $starkit::topdir $dir msgs]]
                }
            } $args]
        }
    }

    # TODO works?
    interp alias {} Source {} ::source -encoding utf-8

    method resource {name args} {
        if {[llength $args] < 1} {
            set args {~ ..}
        }
        catch {Source ~/.wishrc.tcl}
        foreach dir $args {
            catch {Source [file join $dir ${name}rc.tcl]}
        }
    }
    method definition name {
        catch {Source [file join .. ${name}.def]}
    }

}

conf setdir
