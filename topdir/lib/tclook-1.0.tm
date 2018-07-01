package require Tk
package require textutil::adjust

namespace eval tclook {
    foreach ns {object class namespace method command} {
        namespace eval $ns {}
    }
}

proc ::tclook::clearAll {} {
    destroy {*}[dict values [array get [namespace current]::windows]]
}

proc ::tclook::show args {
    foreach name $args {
        _show {object class} [uplevel 1 [list namespace which $name]]
    }
}

proc ::tclook::_show {types data} {
    foreach type $types {
        GetWindow $type $data
    }
}

proc ::tclook::AddRow {w row key val} {
    set k [ttk::label $w.k$row -text $key]
    if {$val eq "-"} {
        set v -
    } else {
        set v [ttk::label $w.v$row -text $val]
    }
    grid $k $v -sticky ew
    return $v
}

proc ::tclook::object::Pane {f obj} {
    set type [namespace tail [namespace current]]
    # TODO decide about other subcommands
    set row 0
    ::tclook::AddRow $f [incr row] name $obj
    ::tclook::AddRow $f [incr row] isa [::tclook::GetIsa $obj]
    foreach key {class namespace} {
        set val [info $type $key $obj]
        ::tclook::Bind [::tclook::AddRow $f [incr row] $key $val] $key
    }
    ::tclook::AddRow $f [incr row] mixins {}
    foreach val [info $type mixins $obj] {
        ::tclook::Bind [::tclook::AddRow $f [incr row] {} $val]
    }
    ::tclook::AddRow $f [incr row] filters {}
    foreach val [info $type filters $obj] {
        set data [list 0 0 $type $obj $val]
        ::tclook::BindMethod [::tclook::AddRow $f [incr row] {} $val] {*}$data
    }
    ::tclook::AddRow $f [incr row] variables {}
    foreach val [info $type variables $obj] {
        ::tclook::AddRow $f [incr row] {} $val
    }
    ::tclook::AddRow $f [incr row] vars {}
    foreach val [info $type vars $obj] {
        ::tclook::AddRow $f [incr row] {} $val
    }
    ::tclook::AddRow $f [incr row] methods {}
    foreach val [info $type methods $obj -all -private] {
        set data [list]
        lappend data [::tclook::IsPrivate $type $obj $val]
        lappend data [::tclook::IsLocal $type $obj $val]
        lappend data $type $obj $val
        ::tclook::BindMethod [::tclook::AddRow $f [incr row] {} $val] {*}$data
    }
}

proc ::tclook::class::Pane {f obj} {
    set type [namespace tail [namespace current]]
    # TODO decide about other subcommands
    set row 0
    ::tclook::AddRow $f [incr row] name $obj
    ::tclook::AddRow $f [incr row] superclass {}
    foreach val [info $type superclass $obj] {
        ::tclook::Bind [::tclook::AddRow $f [incr row] {} $val]
    }
    ::tclook::AddRow $f [incr row] mixins {}
    foreach val [info $type mixins $obj] {
        ::tclook::Bind [::tclook::AddRow $f [incr row] {} $val]
    }
    ::tclook::AddRow $f [incr row] filters {}
    foreach val [info $type filters $obj] {
        set data [list 0 0 $type $obj $val]
        ::tclook::BindMethod [::tclook::AddRow $f [incr row] {} $val] {*}$data
    }
    ::tclook::AddRow $f [incr row] variables {}
    foreach val [info $type variables $obj] {
        ::tclook::AddRow $f [incr row] {} $val
    }
    ::tclook::AddRow $f [incr row] instances {}
    foreach val [info $type instances $obj] {
        ::tclook::Bind [::tclook::AddRow $f [incr row] {} $val]
    }
    ::tclook::AddRow $f [incr row] methods {}
    foreach val [info $type methods $obj -all -private] {
        set data [list]
        lappend data [::tclook::IsPrivate $type $obj $val]
        lappend data [::tclook::IsLocal $type $obj $val]
        lappend data $type $obj $val
        ::tclook::BindMethod [::tclook::AddRow $f [incr row] {} $val] {*}$data
    }
}

proc ::tclook::namespace::Pane {f obj} {
    set row 0
    ::tclook::AddRow $f [incr row] name $obj
    ::tclook::AddRow $f [incr row] vars {}
    foreach val [info vars $obj\::*] {
        ::tclook::AddRow $f [incr row] {} $val
    }
    ::tclook::AddRow $f [incr row] commands {}
    foreach val [info commands $obj\::*] {
        ::tclook::Bind [::tclook::AddRow $f [incr row] {} $val] command
    }
    ::tclook::AddRow $f [incr row] children {}
    foreach val [namespace children $obj] {
        ::tclook::Bind [::tclook::AddRow $f [incr row] {} $val] namespace
    }
}

proc ::tclook::method::Pane {f data} {
    lassign $data type obj name
    set row 0
    set code [info $type methodtype $obj $name]
    lassign [info $type definition $obj $name] args body
    append code " $name {$args} {"
    append code [::textutil::adjust::undent "$body}"]
    ::tclook::AddRow $f [incr row] $code -
}

proc ::tclook::command::Pane {f name} {
    set row 0
    set args [info args $name]
    set body [info body $name]
    append code "proc $name {$args} {"
    append code [::textutil::adjust::undent "$body}"]
    ::tclook::AddRow $f [incr row] $code -
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

proc ::tclook::GetWindow {type data} {
    variable windows
    set key [list $type {*}$data]
    if {![info exists windows($key)] || ![winfo exists $windows($key)]} {
        set w [NewWindow $key]
        set f [ttk::frame $w.f]
        try {
            $type\::Pane $f $data
        } on ok {} {
            grid columnconfigure $f 1 -weight 1
            SetStyle $f $type
            pack $f -expand yes -fill both
            set windows($key) $w
        } on error {msg opts} {
            destroy $w
            if 0 {
                return -options [dict incr opts -level] $msg
            } else {
                return -level 2 -code continue
            }
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
::log::lvSuppressLE i 0
::tclook::clearAll ; package forget tclook ; package require tclook
source -encoding utf-8 automaton-20180628-2.tcl
::tclook::show oo::class

if 0 {
    get <type> window
        key <- type {*}name
        # name is atom or (for method) {type obj val}
        w <- NewWindow
        f <- create frame
        $type\::Pane $f $name
        SetWeight
        SetStyle $type
        pack
        add to windows $key $w
    
    create object Pane (f obj)
        add row name $obj
        add row isa GetIsa
        Bind (add row class (ObjectGetClass $obj)) class
        Bind (add row namespace (ObjectGetNamespace)) namespace
        add row mixins {}
        ObjectGetMixins $obj each (Bind (add row))
        add row filters {}
        ObjectGetFilters $obj each (BindMethod (add row) 0 0 object $obj $val?)
        add row variables {}
        ObjectGetVariables $obj each (add row)
        add row vars {}
        ObjectGetVars $obj each (add row)
        add row methods {}
        ObjectGetMethods $obj each (BindMethod (add row) (P) (L) object $obj)

    create class Pane (f obj)
        add row name $obj
        add row superclass {}
        ClassGetSuperclass $obj each (Bind (add row))
        add row mixins {}
        ClassGetMixins $obj each (Bind (add row))
        add row filters {}
        ClassGetFilters $obj each (BindMethod (add row) 0 0 object $obj $val?)
        add row variables {}
        ClassGetVariables $obj 
        add row instances {}
        ClassGetInstances $obj each (Bind (add row))
        add row methods {}
        ClassGetMethods $obj each (BindMethod (add row) (P) (L) class $obj)
        
    create namespace Pane (f obj)
        add row name $obj
        GetVars $obj each (add row)
        GetCommands $obj each (Bind (add row) command)
        GetNamespaceChildren $obj each (Bind (add row) namespace)

    create method Pane (f (type obj name))
        code <- ${type}GetMethodtype $obj $name
        (args body) <- ${type}GetDefinition $obj $name
        code << $name {$args} {$body}
        BindMethod (add row $code -) (P) (L) $type $obj

    create command Pane (f name)
        add row name $obj
        args <- GetArgs
        body <- GetBody
        code <- proc $name {$args} {$body}
        add row $code -

}
