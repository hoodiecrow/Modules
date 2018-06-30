package require Tk
package require textutil::adjust

namespace eval tclook {
    foreach ns {object class namespace method command} {
        namespace eval $ns {}
    }
}

proc ::tclook::clearAll {} {
    variable windows
    foreach {n v} [array get windows] {
        catch {destroy $v}
    }
}

proc ::tclook::show args {
    foreach name $args {
        _show {object class} [uplevel 1 [list namespace which $name]]
    }
}

proc ::tclook::_show {types name} {
    foreach type $types {
        GetWindow [list $type {*}$name]
    }
}

proc ::tclook::listSingle {w rowVarName type obj key args} {
    upvar 1 $rowVarName row
    incr row
    if {[llength $args] eq 0} {
        set val [info $type $key $obj]
    } else {
        lassign $args val
    }
    set k [ttk::label $w.k$row -text $key]
    set v [ttk::label $w.v$row -text $val]
    ::tclook::Bind $v $key
    grid $k $v -sticky ew
}

proc ::tclook::listMulti {w rowVarName type obj key args} {
    upvar 1 $rowVarName row
    incr row
    grid [ttk::label $w.k$row -text $key] - -sticky ew
    if {[llength $args] eq 0} {
        set vals [info $type $key $obj]
    } else {
        # note that value of key is changed here
        lassign $args vals key
    }
    foreach val $vals {
        incr row
        set k [ttk::label $w.k$row]
        set v [ttk::label $w.v$row -text $val]
        if {$key in {superclass mixins instances}} {
            ::tclook::Bind $v
        } elseif {$key in {namespace command}} {
            ::tclook::Bind $v $key
        } elseif {$key in {filters}} {
            ::tclook::BindMethod $v 0 0 $type $obj $val
        }
        grid $k $v -sticky ew
    }
}

proc ::tclook::listMethods {w rowVarName type obj} {
    upvar 1 $rowVarName row
    incr row
    set key methods
    grid [ttk::label $w.k$row -text $key] - -sticky ew
    set vals [info $type $key $obj -all -private]
    foreach val $vals {
        incr row
        set k [ttk::label $w.k$row]
        set v [ttk::label $w.v$row -text $val]
        ::tclook::BindMethod $v [IsPrivate $type $obj $val] [IsLocal $type $obj $val] $type $obj $val
        grid $k $v -sticky ew
    }
}

proc ::tclook::object::Pane {f obj} {
    set type [namespace tail [namespace current]]
    # TODO decide about other subcommands
    ::tclook::listSingle $f row $type $obj name $obj
    ::tclook::listSingle $f row $type $obj isa [lmap i {class metaclass object} {
        if {[info object isa $i $obj]} {set i} continue
    }]
    ::tclook::listSingle $f row $type $obj class
    ::tclook::listSingle $f row $type $obj namespace
    ::tclook::listMulti $f row $type $obj mixins
    ::tclook::listMulti $f row $type $obj filters
    ::tclook::listMulti $f row $type $obj variables
    ::tclook::listMulti $f row $type $obj vars
    ::tclook::listMethods $f row $type $obj
}

proc ::tclook::class::Pane {f obj} {
    set type [namespace tail [namespace current]]
    # TODO decide about other subcommands
    ::tclook::listSingle $f row $type $obj name $obj
    ::tclook::listMulti $f row $type $obj superclass
    ::tclook::listMulti $f row $type $obj mixins
    ::tclook::listMulti $f row $type $obj filters
    ::tclook::listMulti $f row $type $obj variables
    ::tclook::listMulti $f row $type $obj instances
    ::tclook::listMethods $f row $type $obj
}

proc ::tclook::namespace::Pane {f obj} {
    set type [namespace tail [namespace current]]
    ::tclook::listSingle $f row $type $obj name $obj
    ::tclook::listMulti $f row $type $obj vars [info vars $obj\::*]
    ::tclook::listMulti $f row $type $obj commands [info commands $obj\::*] command
    ::tclook::listMulti $f row $type $obj children [namespace children $obj] namespace
}

proc ::tclook::method::Pane {f data} {
    lassign $data ooc obj name
    lassign [info $ooc definition $obj $name] args body
    set code [info $ooc methodtype $obj $name]
    append code " $name {$args} {"
    append code [::textutil::adjust::undent "$body}"]
    pack [ttk::label $f.code -text $code] -expand 1 -fill both
}

proc ::tclook::command::Pane {f name} {
    # TODO rewrite to look more command-like
    set type [namespace tail [namespace current]]
    set key name
    set val $name
    incr row
    set k [ttk::label $f.k$row -text $key]
    set v [ttk::label $f.v$row -text $val]
    grid $k $v -sticky ew
    lassign  args body
    set key arguments
    set val [info args $name]
    incr row
    set k [ttk::label $f.k$row -text $key]
    set v [ttk::label $f.v$row -text $val]
    grid $k $v -sticky ew
    set key body
    set val [info body $name]
    incr row
    set k [ttk::label $f.k$row -text $key]
    set v [ttk::label $f.v$row -text $val]
    grid $k $v -sticky ew
}

proc ::tclook::BindMethod {w args} {
    set args [lassign $args p l]
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

proc ::tclook::IsPrivate {type obj m} {
    expr {$m ni [info $type methods $obj -all]}
}

proc ::tclook::IsLocal {type obj m} {
    expr {$m in [info $type methods $obj -private]}
}

proc ::tclook::NewWindow title {
    variable wn
    set w [toplevel .t[incr wn]]
    wm minsize $w 270 200
    wm title $w $title
    return $w
}

proc ::tclook::SetStyle {f type} {
    foreach ch [winfo children $f] {
        if {[winfo class $ch] eq "TLabel" && [$ch cget -style] eq {}} {
            $ch config -style $type.TLabel
        }
    }
}

proc ::tclook::GetWindow key {
    variable windows
    set name [lassign $key type]
    if {![info exists windows($key)] || ![winfo exists $windows($key)]} {
        set w [NewWindow $key]
        set f [ttk::frame $w.f]
        try {
            $type\::Pane $f $name
        } on ok {} {
            # TODO check if there is problem with method::Pane not using grid
            grid columnconfigure $f 1 -weight 1
            SetStyle $f $type
            pack $f -expand yes -fill both
            set windows($key) $w
        } on error {msg opts} {
            destroy $w
            if yes {
                return -options [dict incr opts -level] $msg
            }
            return -level 2 -code continue
        }
    }
    raise $windows($key)
    focus $windows($key)
}

proc ::tclook::Init {} {
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
    font configure $fontme {*}[dict merge $fontdict {-family courier -size 12}]
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

cd ~/code/Modules/
tcl::tm::path add topdir/lib/
package require tclook
::tclook::clearAll ; package forget tclook ; package require tclook
source -encoding utf-8 automaton-20180628-2.tcl
::tclook::show oo::class
