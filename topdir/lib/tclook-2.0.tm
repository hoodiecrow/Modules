package require Tk
package require textutil::adjust
package require struct::matrix
package require Tktable

namespace eval tclook {}

# TclOO-based object/class/namespace browser

# NOTE filters are methods, so don't link them from the filters field

proc ::tclook::Init {} {
    variable keys {
        id variables methods namespace vars commands class superclasses
        subclasses mixins instances children
    }
}

proc ::tclook::add {type desc} {
    variable keys
    set values [lmap key $keys {
        switch $key {
            id           { list $type $desc }
            variables    { switch $type object - class { info $type $key $desc } }
            methods      { switch $type object - class { GetMethods $type $desc } }
            namespace    { switch $type object { info $type $key $desc } }
            vars         { switch $type object { info $type $key $desc } namespace { info vars ${desc}::* } }
            commands     { switch $type namespace { info $key ${desc}::* } }
            class        { switch $type object { info $type $key $desc } }
            superclasses { switch $type class { info $type $key $desc } }
            subclasses   { switch $type class { info $type $key $desc } }
            mixins       -
            filters      -
            instances    { switch $type class { info $type $key $desc } }
            children     { switch $type namespace { namespace $key $desc } }
            default {
                ;
            }
        }
    }]
    return $values
}

proc ::tclook::GetMethods {type desc} {
    log::log d -----------------------------
    log::log d [info level 0] 
    set d {}
    set methods [info $type methods $desc]
    log::log d --public--
    log::log d $methods
    foreach method $methods {
        log::log d \$method=$method 
        log::log d "call: [info $type call $desc $method]"
        log::log d "mtyp: [info $type methodtype $desc $method]"
        log::log d "args: [lindex [info $type definition $desc $method] 0]"
    }
    set methods [info $type methods $desc -private]
    log::log d --private--
    log::log d $methods
    foreach method $methods {
        if {$method ni [info $type methods $desc]} {
            log::log d \$method=$method 
            log::log d "call: [info $type call $desc $method]"
            log::log d "mtyp: [info $type methodtype $desc $method]"
            log::log d "args: [lindex [info $type definition $desc $method] 0]"
        }
        if no {
            dict set minfo belongs 0
            if {$method in [info $type methods $desc]} { dict incr minfo belongs }
            if {$method in [info $type methods $desc -private]} { dict incr minfo belongs 2 }
            if {$method ni [info $type methods $desc -all] && $method ni [info $type methods $desc ]} {
                dict incr minfo belongs 4
            } else {
                dict lappend minfo signature [info $type methodtype $desc $method]
                log::log d \$minfo=$minfo 
                dict lappend minfo signature $method
                log::log d [list info $type definition $desc $method]
                dict lappend minfo signature [lindex [info $type definition $desc $method] 0]
            }
            dict set minfo call [info $type call $desc $method]
            dict set d $method $minfo
        }
    }
    set methods [info $type methods $desc -private -all]
    log::log d --inherited--
    log::log d $methods
    foreach method $methods {
        log::log d \$method=$method 
        log::log d "call: [info $type call $desc $method]"
    }
    return $d
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
oo::class create Foo {method foo {a b} {list $b $a}}
oo::class create Bar {superclass Foo ; method Qux {} {my foo m n} ; method quux {} {my foo x y}}
Foo create foo
Bar create bar
::tclook::GetMethods class ::Foo ; ::tclook::GetMethods object ::foo ; ::tclook::GetMethods class ::Bar ; ::tclook::GetMethods object ::bar

::tclook::add object oo::class
::tclook::add class oo::class
::tclook::add namespace ::tcl 

#
#               O  C  N
=======================
id              1  1  1
variables       1  1
methods         1  1
namespace       1
vars            1  1  1
commands              1
class           1
superclasses       1
subclasses         1
mixins          1  1
instances          1
children              1
#

#
# popups for individual methods (incl ctor / dtor) procs
# navigation to connected object class namespace
# TODO add filters back to browser?

# TODO maybe?
#       object      class           namespace   method      procedure
#       =============================================================
# #2:   isa         superclasses    procs       methodtype  'proc'
# #3:   class       subclasses      children    definition  <-
# #4:   namespace   instances       commands
# #5:   vars        ..              <-
# #6:   mixins      <-
# #7:   filters     <-
# #8:   variables   <-
# #9:   methods     <-
#

# TODO an entry to enable calls to info object|class call?
# similar for info forward

proc ::tclook::add {m type desc} {
    variable keys
    set values [lmap key $keys {
        switch $key {
            id           { list $type $desc }
            isa          { switch $type object { GetIsa $desc } }
            class        { switch $type object { info $type $key $desc } }
            superclasses { switch $type class { info $type $key $desc } }
            subclasses   { switch $type class { info $type $key $desc } }
            namespace    { switch $type object { info $type $key $desc } }
            mixins       -
            filters      -
            variables    { switch $type object - class { info $type $key $desc } }
            vars         { switch $type object { info $type $key $desc } namespace { info vars ${desc}::* } }
            instances    { switch $type class { info $type $key $desc } }
            methods      { switch $type object - class { GetMethods $type $desc } }
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

proc ::tclook::__GetMethods {type desc} {
    # TODO change to return dict of name->bits where bits indicate
    # membership in {{} -p -a} (all methods are members of {-p -a})
    set methodlist {-all -private}
    info $type methods $desc {*}$methodlist
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
$m add columns [llength $::tclook::keys]
::tclook::add $m object oo::class
::tclook::add $m class oo::class
::tclook::add $m namespace ::tcl 
$m serialize

# columns:
# id
# type
# name
# isa
# class [link $key $val]
# superclass [link class $val]
# namespace [link $key $val]
# mixins [link class $val]
# filters NOT [link method [list $type $desc $val]]
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

