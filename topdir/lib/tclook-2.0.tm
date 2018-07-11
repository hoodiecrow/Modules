package require Tk
package require textutil::adjust
package require struct::matrix
package require Tktable

namespace eval tclook {}

# columns:
# id
# type
# name
# isa
# class [link $key $val]
# superclass [link class $val]
# namespace [link $key $val]
# mixins [link class $val]
# filters [link method [list $type $desc $val]]
# variables
# vars
# instances [link class $val]
# methods [link method [list $type $desc $val]]
# methodtype
# definition
# procs [link procedure $procname]
# commands
# children [link namespace $nsname]
#

proc ::tclook::Init {} {
    variable keys {
        id isa class superclass namespace mixins filters variables vars
        instances methods methodtype definition procs commands children
    }
}

proc ::tclook::add {m type desc} {
    variable keys
    set methodlist {-all -private}
    set values [lmap key $keys {
        switch $key {
            id           { list $type $desc }
            isa          { switch $type object { GetIsa $desc } }
            class        { switch $type object { info $type $key $desc } }
            superclasses { switch $type class { info $type $key $desc } }
            namespace    { switch $type object { info $type $key $desc } }
            mixins       -
            filters      -
            variables    { switch $type object - class { info $type $key $desc } }
            vars         { switch $type object { info $type $key $desc } namespace { info vars ${desc}::* } }
            instances    { switch $type class { info $type $key $desc } }
            methods      { switch $type object - class { info $type $key $desc {*}$methodlist} }
            methodtype   { switch $type method { info [lindex $desc 0] $key {*}[lrange $desc 1 end] } procedure { format proc }}
            definition   { switch $type method { info [lindex $desc 0] $key {*}[lrange $desc 1 end] } procedure { list [info args $desc] [info body $desc] } }
            procs        { switch $type namespace { info $key ${desc}::* } }
            commands     { switch $type namespace { info $key ${desc}::* } }
            children     { switch $type namespace { namespace $key $desc } }
            default {
                ;
            }
        }
    }]
    puts $values
    $m add row $values
}

proc ::tclook::GetIsa obj {
    lmap i {class metaclass object} {
        if {[info object isa $i $obj]} {set i} continue
    }
}

::tclook::Init

return

package require log
cd ~/code/Modules/
tcl::tm::path add topdir/lib/
package require tclook
::log::lvSuppressLE i 0
package forget tclook ; package require tclook
source -encoding utf-8 automaton-20180628-2.tcl
catch { $m destroy }
set m [::struct::matrix]
$m add columns [llength $::tclook::keys]
::tclook::add $m object oo::class
::tclook::add $m class oo::class
::tclook::add $m namespace ::tcl 
$m serialize
