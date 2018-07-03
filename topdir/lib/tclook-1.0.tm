package require Tk
package require textutil::adjust

namespace eval tclook {}

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

proc ::tclook::_show args {
    log::log d [info level 0] 
    # Bring up a pane if it has been opened before, or else try to make a new
    # one. Catch any errors raised by creating a pane, unless -showerrors is
    # given.
    variable windows
    if {[lindex $args 0] eq "-showerrors"} {
        set showErrors true
        lassign $args - type data
    } else {
        set showErrors false
        lassign $args type data
    }
    set key [list $type {*}$data]
    if {![info exists windows($key)] || ![winfo exists $windows($key)]} {
        # Create a PaneMaker instance. It will do most of the work of creating
        # a pane, and provide the 'add' method to insert items in it.
        set pane [PaneMaker new]
        try {
            $pane openWindow $key
        } on ok {} {
            # It worked, transfer the window path to the windows array.
            set windows($key) [$pane window]
        } on error {msg opts} {
            # It didn't work, pass or catch the error.
            if {$showErrors} {
                return -options [dict incr opts -level] $msg
            }
        } finally {
            catch { $pane destroy }
        }
    }
    # One way or another, we now have a window. Bring it up.
    raise $windows($key)
    focus $windows($key)
}

namespace eval ::tclook::Pane {
    namespace export {[a-z]*}
    variable map {}
    foreach type {object class namespace method command} {
        lappend map $type ${type}Pane
    }
    namespace ensemble create -map $map

proc objectPrint data {
    set maxkey [::tcl::mathfunc::max {*}[lmap key [dict keys $data] {
        string length $key
    }]]
    dict for {key val} $data {
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

proc objectShow data {
    # TODO feed a data dictionary to a proc that shows it as a pane (tk::frame
    # with tk::labels), fixing bindtags and -background/-font
}

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

proc objectPane {pane obj} {
    set type object
    # TODO decide about other subcommands
    $pane add name $obj
    $pane add isa [::tclook::GetIsa $obj]
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
        $pane add {} $val BindMethod 0 0 $type $obj $val
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
        $pane add {} $val BindMethod $type $obj $val
    }
}

proc classPane {pane obj} {
    set type class
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
        $pane add {} $val BindMethod 0 0 $type $obj $val
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
        $pane add {} $val BindMethod $type $obj $val
    }
}

proc namespacePane {pane obj} {
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

proc methodPane {pane data} {
    lassign $data type obj name
    set code [info $type methodtype $obj $name]
    lassign [info $type definition $obj $name] args body
    append code " $name {$args} {"
    append code [::textutil::adjust::undent "$body}"]
    $pane add $code -
}

proc commandPane {pane name} {
    set code proc
    set args [info args $name]
    set body [info body $name]
    append code " $name {$args} {"
    append code [::textutil::adjust::undent "$body}"]
    $pane add $code -
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
    # This class creates an introspection pane and helps the type-specific
    # command furnish it. If the pane's path is passed out of the class using
    # the 'window' method, the window is detached from the instance. If not,
    # the window gets destroyed when the instance is.
    variable w frame rownum
    constructor args {}
    destructor {
        destroy $w
    }
    method openWindow title {
        # The 'title' argument is a list. The first element is the pane type
        # and the rest of the elements is the data set to determine its
        # contents: for many panes it is simply the qualified name.
        set w [toplevel .t[incr ::tclook::wn]]
        wm minsize $w 270 200
        wm title $w $title
        set frame [ttk::frame $w.f]
        pack $frame -expand yes -fill both
        set data [lassign $title type]
        # This action might fail if any introspection step fails.
        try {
            ::tclook::Pane $type [self] $data
        } on ok {} {
            grid columnconfigure $frame 1 -weight 1
            foreach ch [winfo children $frame] {
                if {[winfo class $ch] eq "TLabel" && [$ch cget -style] eq {}} {
                    $ch config -style $type.TLabel
                }
            }
        }
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
        set win $w
        set w {}
        return $win
    }
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
