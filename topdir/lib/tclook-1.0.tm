package require Tk
package require textutil::adjust

namespace eval tclook {
    foreach ns {object class namespace method command} {
        namespace eval $ns {
            namespace path ::tclook
        }
    }
}

proc ::tclook::clearAll {} {
    # Close any still-open windows that have been opened by us.
    variable windows
    destroy {*}[dict values [array get windows]]
}

proc ::tclook::show args {
    # Take a sequence of names and attempt to open then as object panes and as
    # class panes.
    foreach name $args {
        set name [uplevel 1 [list namespace which $name]]
        _show object $name
        _show class $name
    }
}

proc ::tclook::_show {type data} {
    # Open a pane given a type and a name. Does not raise errors.
    GetWindow $type $data
}

proc ::tclook::object::Pane {pane obj} {
    set type [namespace tail [namespace current]]
    # TODO decide about other subcommands
    $pane add name $obj
    $pane add isa [GetIsa $obj]
    foreach key {class namespace} {
        set val [info $type $key $obj]
        $pane add $key $val Bind $key
    }
    $pane add mixins
    foreach val [info $type mixins $obj] {
        $pane add {} $val Bind 
    }
    $pane add filters
    foreach val [info $type filters $obj] {
        set data [list 0 0 $type $obj $val]
        $pane add {} $val BindMethod {*}$data
    }
    $pane add variables
    foreach val [info $type variables $obj] {
        $pane add {} $val
    }
    $pane add vars
    foreach val [info $type vars $obj] {
        $pane add {} $val
    }
    $pane add methods
    foreach val [info $type methods $obj -all -private] {
        set data [list]
        lappend data [IsPrivate $type $obj $val]
        lappend data [IsLocal $type $obj $val]
        lappend data $type $obj $val
        $pane add {} $val BindMethod {*}$data
    }
}

proc ::tclook::class::Pane {pane obj} {
    set type [namespace tail [namespace current]]
    # TODO decide about other subcommands
    $pane add name $obj
    $pane add superclass
    foreach val [info $type superclass $obj] {
        $pane add {} $val Bind 
    }
    $pane add mixins
    foreach val [info $type mixins $obj] {
        $pane add {} $val Bind 
    }
    $pane add filters
    foreach val [info $type filters $obj] {
        set data [list 0 0 $type $obj $val]
        $pane add {} $val BindMethod {*}$data
    }
    $pane add variables
    foreach val [info $type variables $obj] {
        $pane add {} $val
    }
    $pane add instances
    foreach val [info $type instances $obj] {
        $pane add {} $val Bind 
    }
    $pane add methods
    foreach val [info $type methods $obj -all -private] {
        set data [list]
        lappend data [IsPrivate $type $obj $val]
        lappend data [IsLocal $type $obj $val]
        lappend data $type $obj $val
        $pane add {} $val BindMethod {*}$data
    }
}

proc ::tclook::namespace::Pane {pane obj} {
    $pane add name $obj
    $pane add vars
    foreach val [info vars $obj\::*] {
        $pane add {} $val
    }
    $pane add commands
    foreach val [info commands $obj\::*] {
        $pane add {} $val Bind command
    }
    $pane add children
    foreach val [namespace children $obj] {
        $pane add {} $val Bind namespace
    }
}

proc ::tclook::method::Pane {pane data} {
    lassign $data type obj name
    set code [info $type methodtype $obj $name]
    lassign [info $type definition $obj $name] args body
    append code " $name {$args} {"
    append code [::textutil::adjust::undent "$body}"]
    $pane add $code -
}

proc ::tclook::command::Pane {pane name} {
    set code proc
    set args [info args $name]
    set body [info body $name]
    append code " $name {$args} {"
    append code [::textutil::adjust::undent "$body}"]
    $pane add $code -
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

oo::class create ::tclook::Pane {
    variable type w frame rownum
    constructor args {
        lassign $args type title
        my NewWindow $title
        set frame [ttk::frame $w.f]
        set rownum 0
    }
    method destroyWindow {} {
        destroy $w
    }
    method NewWindow title {
        set w [toplevel .t[incr ::tclook::wn]]
        wm minsize $w 270 200
        wm title $w $title
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
    method window {} {
        grid columnconfigure $frame 1 -weight 1
        foreach ch [winfo children $frame] {
            if {[winfo class $ch] eq "TLabel" && [$ch cget -style] eq {}} {
                $ch config -style $type.TLabel
            }
        }
        pack $frame -expand yes -fill both
        return $w
    }
}

proc ::tclook::GetWindow {type data} {
    variable windows
    set key [list $type {*}$data]
    if {![info exists windows($key)] || ![winfo exists $windows($key)]} {
        set pane [Pane new $type $key]
        try {
            $type\::Pane $pane $data
        } on ok {} {
            set windows($key) [$pane window]
        } on error {msg opts} {
            $pane destroyWindow
            if 0 {
                return -options [dict incr opts -level] $msg
            } else {
                return -level 2 -code continue
            }
        } finally {
            # Destroy Pane instance, leaving window behind.
            $pane destroy
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

package require log
cd ~/code/Modules/
tcl::tm::path add topdir/lib/
package require tclook
::log::lvSuppressLE i 0
::tclook::clearAll ; package forget tclook ; package require tclook
source -encoding utf-8 automaton-20180628-2.tcl
::tclook::show oo::class
