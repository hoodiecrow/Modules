
interp alias {} Source {} source -encoding utf-8

oo::object create conf
oo::objdefine conf {
    method msgcat {ns args} {
        if {[catch {package present msgcat}]} {
            interp alias {} ::mc {} format
        } else {
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
            #return -code error [mc {illegal expand mode %s} foo]
            #error [::msgcat::mc {illegal expand mode %s} foo]
        }
    }
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
