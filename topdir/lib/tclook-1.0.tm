package require Tk
package require textutil::adjust

namespace eval tclook {}

proc ::tclook::clearAll {} {
    # Close any still-open windows that have been opened by us.
    variable windows
    destroy {*}[dict values [array get windows]]
}

proc ::tclook::show args {
    # 'args' is a sequence of names. Attempt to resolve each name as a
    # qualified command name, and to open a pane for the name as an object, a
    # class, a namespace, or a procedure. 
    foreach name $args {
        set _name [uplevel 1 [list namespace which $name]]
        if {$_name ne {}} {
            set name $_name
        }
        if {[info object isa object $name]} {
            _show object $name
            if {[info object isa class $name]} {
                _show class $name
            }
        } elseif {[namespace exists $name]} {
            _show namespace $name
        } elseif {$name in [info procs [namespace qualifiers $name]::*]} {
            _show command $name
        } else {
            return -code error [format {unknown thing %s} $name]
        }
    }
}

proc ::tclook::_show args {
    # Bring up a pane if it has been opened before, or else try to make a new
    # one. Catch any errors raised by creating a pane, unless -showerrors is
    # given.
    variable windows
    variable wn
    set key $args
    if {![info exists windows($key)] || ![winfo exists $windows($key)]} {
        set w [toplevel .t[incr wn]]
        wm minsize $w 270 200
        wm title $w $key
        set frame [ttk::frame $w.f]
        pack $frame -expand yes -fill both
        set pane [PaneMaker new $frame]
        ::tclook::Pane {*}$key $pane
        catch { $pane destroy }
        grid columnconfigure $frame 1 -weight 1
        foreach ch [winfo children $frame] {
            if {[winfo class $ch] eq "TLabel" && [$ch cget -style] eq {}} {
                $ch config -style [lindex $key 0].TLabel
            }
        }
        set windows($key) $w
    }
    # One way or another, we now have a window. Bring it up.
    raise $windows($key)
    focus $windows($key)
}

namespace eval ::tclook::Print {
    namespace export {[a-z]*}
    variable map {}
    foreach type {object class namespace method command} {
        lappend map $type ${type}Print
    }
    namespace ensemble create -map $map

    proc objectPrint data {
        set info [::tclook::List object $data]
        set maxkey [::tcl::mathfunc::max {*}[lmap key [dict keys $info] {
            string length $key
        }]]
        dict for {key val} $info {
            if {$key eq "type"} {
                continue
            }
            lassign $val kind values
            if {$kind eq "L"} {
                set values [join $values ", "]
            }
            puts [format {%-*s %s} $maxkey $key $values]
        }
    }

    proc classPrint data {
        set info [::tclook::List class $data]
        set maxkey [::tcl::mathfunc::max {*}[lmap key [dict keys $info] {
            string length $key
        }]]
        dict for {key val} $info {
            if {$key eq "type"} {
                continue
            }
            lassign $val kind values
            if {$kind eq "L"} {
                set values [join $values ", "]
            }
            puts [format {%-*s %s} $maxkey $key $values]
        }
    }

    proc namespacePrint data {
        set info [::tclook::List namespace $data]
        set maxkey [::tcl::mathfunc::max {*}[lmap key [dict keys $info] {
            string length $key
        }]]
        dict for {key val} $info {
            if {$key eq "type"} {
                continue
            }
            lassign $val kind values
            if {$kind eq "L"} {
                set values [join $values ", "]
            }
            puts [format {%-*s %s} $maxkey $key $values]
        }
    }

    proc methodPrint data {
        set info [::tclook::List method $data]
        set info [dict map {- val} $info {lindex $val 1}]
        dict with info {
            puts "$mtype $name {$args} {$body}"
        }
    }

    proc commandPrint name {
        set info [::tclook::List command $name]
        set info [dict map {- val} $info {lindex $val 1}]
        dict with info {
            puts "proc $name {$args} {$body}"
        }
    }

}

namespace eval ::tclook::List {
    namespace export {[a-z]*}
    variable map {}
    foreach type {object class namespace method command} {
        lappend map $type ${type}List
    }
    namespace ensemble create -map $map

    proc objectList obj {
        set type object
        # TODO decide about other subcommands
        dict set result type S $type
        dict set result name S $obj
        dict set result isa S [::tclook::GetIsa $obj]
        foreach key {class namespace} {
            dict set result $key S [info $type $key $obj]
        }
        foreach key {mixins filters variables vars} {
            dict set result $key L [info $type $key $obj]
        }
        dict set result methods L [info $type methods $obj -all -private]
    }

    proc classList obj {
        set type class
        # TODO decide about other subcommands
        dict set result type S $type
        dict set result name S $obj
        dict set result superclass S [info $type superclass $obj]
        foreach key {mixins filters variables instances} {
            dict set result $key L [info $type $key $obj]
        }
        dict set result methods L [info $type methods $obj -all -private]
    }

    proc namespaceList obj {
        dict set result type S namespace
        dict set result name S $obj
        dict set result vars L [info vars $obj\::*]
        dict set result commands L [info commands $obj\::*]
        dict set result children L [namespace children $obj]
    }

    proc methodList data {
        lassign $data type obj name
        dict set result type S method
        dict set result mtype S [info $type methodtype $obj $name]
        dict set result name S $name
        lassign [info $type definition $obj $name] args body
        dict set result args S $args
        dict set result body S [string trimright [::textutil::adjust::undent $body\x7f] \x7f]
    }

    proc commandList name {
        dict set result type S command
        dict set result name S $name
        dict set result args S [info args $name]
        dict set result body S [string trimright [::textutil::adjust::undent [info body $name]\x7f] \x7f]
    }

}

namespace eval ::tclook::Pane {
    namespace export {[a-z]*}
    variable map {}
    foreach type {object class namespace method command} {
        lappend map $type ${type}Pane
    }
    namespace ensemble create -map $map

    proc objectPane {data pane} {
        set type object
        set info [::tclook::List ${type} $data]
        set info [dict map {- val} $info {lindex $val 1}]
        $pane add name [dict get $info name]
        $pane add isa  [dict get $info isa]
        foreach key {class namespace} {
            $pane add $key [dict get $info $key] Bind $key
        }
        $pane add mixins
        foreach val [dict get $info mixins] {
            $pane add {} $val Bind
        }
        $pane add filters
        foreach val [dict get $info filters] {
            $pane add {} $val BindMethod 0 0 $type [dict get $info name] $val
        }
        foreach key {variables vars} {
            $pane add $key
            foreach val [dict get $info $key] {
                $pane add {} $val
            }
        }
        $pane add methods
        foreach val [dict get $info methods] {
            $pane add {} $val BindMethod $type [dict get $info name] $val
        }
    }

    proc classPane {data pane} {
        set type class
        set info [::tclook::List ${type} $data]
        set info [dict map {- val} $info {lindex $val 1}]
        $pane add name [dict get $info name]
        $pane add superclass [dict get $info superclass] Bind class
        $pane add mixins
        foreach val [dict get $info mixins] {
            $pane add {} $val Bind
        }
        $pane add filters
        foreach val [dict get $info filters] {
            $pane add {} $val BindMethod 0 0 $type [dict get $info name] $val
        }
        $pane add variables
        foreach val [dict get $info variables] {
            $pane add {} $val
        }
        $pane add instances
        foreach val [dict get $info instances] {
            $pane add {} $val Bind
        }
        $pane add methods
        foreach val [dict get $info methods] {
            $pane add {} $val BindMethod $type [dict get $info name] $val
        }
    }

    proc namespacePane {data pane} {
        set type namespace
        set info [::tclook::List ${type} $data]
        set info [dict map {- val} $info {lindex $val 1}]
        $pane add name [dict get $info name]
        $pane add vars
        foreach val [dict get $info vars] {
            $pane add {} $val
        }
        $pane add commands
        foreach val [dict get $info commands] {
            $pane add {} $val Bind command
        }
        $pane add children
        foreach val [dict get $info children] {
            $pane add {} $val Bind namespace
        }
    }

    proc methodPane {data pane} {
        set info [::tclook::List method $data]
        set info [dict map {- val} $info {lindex $val 1}]
        dict with info {
            $pane add "$mtype $name {$args} {$body}" -
        }
    }

    proc commandPane {name pane} {
        set info [::tclook::List command $name]
        set info [dict map {- val} $info {lindex $val 1}]
        dict with info {
            $pane add "proc $name {$args} {$body}" -
        }
    }

}

proc ::tclook::BindMethod {w args} {
    if {[llength $args] eq 5} {
        set args [lassign $args p l]
    } else {
        set p [IsPrivate {*}$args]
        set l [IsLocal {*}$args]
    }
    $w config -style [lindex $args 0]$p$l.TLabel
    bind $w <1> [list ::tclook::_show method $args]
    $w config -cursor hand2
}

proc ::tclook::Bind {w {label wobj} {cursor hand2}} {
    if {$label ni {name isa}} {
        bindtags $w [linsert [bindtags $w] 0 ${label}Popup]
        $w config -cursor $cursor
    }
}

proc ::tclook::GetIsa obj {
    lmap i {class metaclass object} {
        if {[info object isa $i $obj]} {set i} continue
    }
}

proc ::tclook::IsPrivate {type obj m} {
    expr {$m ni [concat [info $type methods $obj] [info $type methods $obj -all]]}
}

proc ::tclook::IsLocal {type obj m} {
    expr {$m in [concat [info $type methods $obj] [info $type methods $obj -private]]}
}

oo::class create ::tclook::PaneMaker {
    variable frame rownum
    constructor args {
        lassign $args frame
    }
    method add {key {val {}} args} {
        incr rownum
        set k [ttk::label $frame.k$rownum -text $key]
        if {$val eq "-"} {
            set v -
        } else {
            set v [ttk::label $frame.v$rownum -text $val]
        }
        grid $k $v -sticky ew
        if {[llength $args] > 0} {
            namespace eval ::tclook [linsert $args 1 $v]
        }
        return $v
    }
}

proc ::tclook::Init {} {
    # TODO this method needs an overhaul
    variable windows
    array set windows {}
    foreach {style color} {
        object wheat
        object00 wheat
        object01 wheat
        object10 wheat
        object11 wheat
        class lavender
        class00 lavender
        class01 lavender
        class10 lavender
        class11 lavender
        namespace DarkSeaGreen1
        method {lemon chiffon}
        command khaki1
    } {
        ttk::style configure $style.TLabel -background $color
    }
    foreach f {00 01 10 11 me} {
        set font$f [font create]
    }
    set fontdict [font actual [ttk::style lookup TLabel -font]]
    font configure $font00 {*}[dict merge $fontdict {-underline 1}]
    font configure $font01 {*}$fontdict
    font configure $font10 {*}[dict merge $fontdict {-slant italic -underline 1}]
    font configure $font11 {*}[dict merge $fontdict {-slant italic}]
    foreach type {object class} {
        foreach f {00 01 10 11} {
            ttk::style configure $type$f.TLabel -font [set font$f]
        }
    }
    font configure $fontme {*}[dict merge $fontdict {-family courier -size 11}]
    ttk::style configure method.TLabel -font $fontme

    bind wobjPopup <1> {::tclook::show [%W cget -text]}
    foreach tag {classPopup mixinsPopup superclassPopup} {
        bind $tag <1> {::tclook::_show class [%W cget -text]}
    }
    foreach tag {namespace command} {
        bind ${tag}Popup <1> [format {::tclook::_show %s [%%W cget -text]} $tag]
    }
}

::tclook::Init

return

package require log
cd ~/code/Modules/
tcl::tm::path add topdir/lib/
package require tclook
::log::lvSuppressLE i 0
catch { ::tclook::PaneMaker destroy } ; ::tclook::clearAll ; package forget tclook ; package require tclook
source -encoding utf-8 automaton-20180628-2.tcl
::tclook::show oo::class
