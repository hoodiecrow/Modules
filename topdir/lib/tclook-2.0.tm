package require Tk
package require textutil::adjust
package require struct::matrix
package require Tktable

namespace eval tclook {}

# columns:
# id ({<type> <descriptor>})
# type ([lindex $id 0])
# name ([lindex $id 1])
# isa (O:[GetIsa $name])
# class (O:[info $type $key $name] -> [link $key $val])
# superclass (C:[info $type $key $name] -> [link class $val])
# namespace (O:[info $type $key $name] -> [link $key $val])
# mixins (OC:[info $type $key $name] -> [link class $val])
# filters (OC:[info $type $key $name] -> [link method [list $type $val]])
# variables (OC:[info $type $key $name])
# vars (O:[info $type $key $name] N:[info vars ${name}\::*])
# instances (C:[info $type $key $name] -> [link class $val])
# methods (OC:[info $type $key $name -all -private] -> [link method [list $type $val]])
# methodtype (M:[info $type $key $name $methodname])
# definition (M:[info $type $key $name $methodname] P:[list [info args $procname] [info body $procname]])
# procs (N:[info $key ${name}\::*] -> [link procedure $procname])
# commands (N:[info $key ${name}\::*])
# children (N:[::namespace children $name] -> [link namespace $nsname])
#

proc ::tclook::add {m type desc} {
    set methodlist {-all -private}
    set keys {
        id type name isa class superclass namespace mixins filters variables
        vars instances methods methodtype definition procs commands children
    }
    set values [lmap key $keys {
        switch $key {
            id         { list $type $desc }
            type       { set type }
            name       { set desc }
            isa        { switch $type object { GetIsa $desc } }
            class      { switch $type object { info $type $key $desc } }
            superclass { switch $type class { info $type $key $desc } }
            namespace  { switch $type object { info $type $key $desc } }
            mixins     -
            filters    -
            variables  { switch $type object - class { info $type $key $desc } }
            vars       { switch $type object { info $type $key $desc } namespace { info vars ${desc}::* } }
            instances  { switch $type class { info $type $key $desc } }
            methods    { switch $type object - class { info $type $key $desc {*}$methodlist} }
            methodtype { switch $type method { info [lindex $desc 0] $key {*}[lrange $desc 1 end] } }
            definition { switch $type method { info [lindex $desc 0] $key {*}[lrange $desc 1 end] } procedure { list [info args $desc] [info body $desc] } }
            procs      { switch $type namespace { info $key ${desc}::* } }
            commands   { switch $type namespace { info $key ${desc}::* } }
            children   { switch $type namespace { namespace $key $desc } }
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
$m add columns 18
::tclook::add $m object oo::class
::tclook::add $m class oo::class
::tclook::add $m namespace ::tcl 
$m serialize
