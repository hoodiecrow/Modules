package require Tk

namespace eval tclook {
    variable wn

    foreach {ns color} {
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
        namespace eval $ns {}
        ttk::style configure $ns.TLabel -background $color
    }
    foreach f {00 01 10 11} {
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

    bind wobjPopup <1> {::tclook::show [%W cget -text]}
    foreach tag {classPopup mixinsPopup superclassPopup} {
        bind $tag <1> {::tclook::_show class [%W cget -text]}
    }
    foreach tag {namespace command} {
        bind ${tag}Popup <1> [format {::tclook::_show %s [%%W cget -text]} $tag]
    }
}

proc ::tclook::clearAll {} {
    variable windows
    if {[info exists windows]} {
        foreach {n v} [array get windows] {
            catch {destroy $v}
        }
    }
}

proc ::tclook::show args {
    foreach name $args {
        _show {object class} [uplevel 1 [list namespace which -command $name]]
    }
}

proc ::tclook::_show {types name} {
    variable windows
    foreach type $types {
        set key [list $type {*}$name]
        if {![info exists windows($key)] || ![winfo exists $windows($key)]} {
            set w [NewWindow]
            try {
                [namespace current]::$type\::Pane $w $name
            } on ok f {
                foreach ch [winfo children $f] {
                    if {[winfo class $ch] eq "TLabel" && [$ch cget -style] eq {}} {
                        $ch config -style $type.TLabel
                    }
                }
                wm title $w $key
                pack $f -expand yes -fill both
                set windows($key) $w
            } on error {msg opts} {
                destroy $w
                if no {
                    return -options [dict incr opts -level] $msg
                }
                continue
            }
        }
        raise $windows($key)
        focus $windows($key)
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
    set k [ttk::label $w.k$row -text methods]
    grid $k - -sticky ew
    foreach method [info $type methods $obj -all -private] {
        incr row
        set k [ttk::label $w.k$row]
        set v [ttk::label $w.v$row -text $method]
        ::tclook::BindMethod $v [IsPrivate $type $obj $method] [IsLocal $type $obj $method] $type $obj $method
        grid $k $v -sticky ew
    }
}

proc ::tclook::object::Pane {w obj} {
    set f [ttk::frame $w.f]
    set type object
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
    grid columnconfigure $f 1 -weight 1
    return $f
}

proc ::tclook::class::Pane {w obj} {
    set f [ttk::frame $w.f]
    set type class
    # TODO decide about other subcommands
    ::tclook::listSingle $f row $type $obj name $obj
    ::tclook::listMulti $f row $type $obj superclass
    ::tclook::listMulti $f row $type $obj mixins
    ::tclook::listMulti $f row $type $obj filters
    ::tclook::listMulti $f row $type $obj variables
    ::tclook::listMulti $f row $type $obj instances
    ::tclook::listMethods $f row $type $obj
    grid columnconfigure $f 1 -weight 1
    return $f
}

proc ::tclook::namespace::Pane {w obj} {
    set f [ttk::frame $w.f]
    set type namespace
    ::tclook::listSingle $f row $type $obj name $obj
    ::tclook::listMulti $f row $type $obj vars [info vars $obj\::*]
    ::tclook::listMulti $f row $type $obj commands [info commands $obj\::*] command
    ::tclook::listMulti $f row $type $obj children [namespace children $obj] namespace
    grid columnconfigure $f 1 -weight 1
    return $f
}

proc ::tclook::method::Pane {w data} {
    # TODO rewrite to look more method-like
    lassign $data ooc obj name
    set type method
    set f [ttk::frame $w.f]
    set key name
    set val $name
    incr row
    set k [ttk::label $f.k$row -text $key]
    set v [ttk::label $f.v$row -text $val]
    grid $k $v -sticky ew
    lassign [info $ooc definition $obj $name] args body
    set key arguments
    set val $args
    incr row
    set k [ttk::label $f.k$row -text $key]
    set v [ttk::label $f.v$row -text $val]
    grid $k $v -sticky ew
    set key body
    set val $body
    incr row
    set k [ttk::label $f.k$row -text $key]
    set v [ttk::label $f.v$row -text $val]
    grid $k $v -sticky ew
    set key type
    set val [info $ooc methodtype $obj $name]
    incr row
    set k [ttk::label $f.k$row -text $key]
    set v [ttk::label $f.v$row -text $val]
    grid $k $v -sticky ew
    grid columnconfigure $f 1 -weight 1
    return $f
}

proc ::tclook::command::Pane {w name} {
    # TODO rewrite to look more command-like
    set type command
    set f [ttk::frame $w.f]
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
    grid columnconfigure $f 1 -weight 1
    return $f
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

proc ::tclook::Tick val {
    if {$val} {
        return \u2713
    }
}

proc ::tclook::IsPrivate {type obj m} {
    expr {$m ni [info $type methods $obj -all]}
}

proc ::tclook::IsLocal {type obj m} {
    expr {$m in [info $type methods $obj -private]}
}

proc ::tclook::NewWindow {} {
    variable wn
    set w [toplevel .t[incr wn]]
    wm minsize $w 270 200
    return $w
}
