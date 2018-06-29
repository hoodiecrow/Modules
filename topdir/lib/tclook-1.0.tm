package require Tk

namespace eval tclook {
    variable wn

    foreach {ns color} {
        object wheat
        class lavender
        namespace DarkSeaGreen1
        method {lemon chiffon}
        command khaki1
    } {
        namespace eval $ns {}
        ttk::style configure $ns.TLabel -background $color
    }
    namespace eval object {}

    bind wobjPopup <1> {::tclook::show [%W cget -text]}
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
    if no {
        tk_messageBox -message [info level 0] 
    }
    variable windows
    foreach type $types {
        set key [list $type {*}$name]
        if {![info exists windows($key)] || ![winfo exists $windows($key)]} {
            set w [NewWindow]
            try {
                [namespace current]::$type\::Pane $w $name
            } on ok f {
                foreach ch [winfo children $f] {
                    if {[winfo class $ch] eq "TLabel"} {
                        $ch config -style $type.TLabel
                    }
                }
                wm title $w $key
                pack $f -expand yes -fill both
                set windows($key) $w
            } on error {} {
                destroy $w
                continue
            }
        }
        raise $windows($key)
        focus $windows($key)
    }
}

proc ::tclook::object::Pane {w obj} {
    set f [ttk::frame $w.f]
    set type object
    # TODO decide about other subcommands
    foreach key {name isa class namespace mixins filters variables vars} {
        if {$key eq "name"} {
            set val $obj
        } elseif {$key eq "isa"} {
            set val [lmap i {class metaclass object} {
                if {[info object isa $i $obj]} {set i} continue
            }]
        } else {
            set val [info $type $key $obj]
        }
        incr row
        set k [ttk::label $f.k$row -text $key]
        set v [ttk::label $f.v$row -text $val]
        switch $key {
            class     { ::tclook::Bind $v }
            namespace { ::tclook::Bind $v namespace $val}
        }
        grid $k $v - - -sticky ew
    }
    ::tclook::listMethods $f row $type $obj
    grid columnconfigure $f 1 -weight 1
    return $f
}

proc ::tclook::class::Pane {w obj} {
    set f [ttk::frame $w.f]
    set type class
    # TODO decide about other subcommands
    foreach key {name superclasses mixins filters variables} {
        if {$key eq "name"} {
            set val $obj
        } else {
            set val [info $type $key $obj]
        }
        incr row
        set k [ttk::label $f.k$row -text $key]
        set v [ttk::label $f.v$row -text $val]
        grid $k $v - - -sticky ew
    }
    # instances
    incr row
    set k [ttk::label $f.k$row -text instances]
    set v [ttk::label $f.v$row -text name]
    grid $k $v - - -sticky ew
    foreach instance [info $type instances $obj] {
        incr row
        set k [ttk::label $f.k$row]
        set v [ttk::label $f.v$row -text $instance]
        ::tclook::Bind $v
        grid $k $v - - -sticky ew
    }
    ::tclook::listMethods $f row $type $obj
    grid columnconfigure $f 1 -weight 1
    return $f
}

proc ::tclook::listMethods {w rowVarName type obj} {
    upvar 1 $rowVarName row
    incr row
    set k [ttk::label $w.k$row -text methods]
    set v [ttk::label $w.v$row -text name]
    set p [ttk::label $w.p$row -text P]
    set l [ttk::label $w.l$row -text L]
    grid $k $v $p $l -sticky ew
    foreach method [info $type methods $obj -all -private] {
        incr row
        set k [ttk::label $w.k$row]
        set v [ttk::label $w.v$row -text $method]
        set p [ttk::label $w.p$row -text [Tick [IsPrivate $type $obj $method]]]
        set l [ttk::label $w.l$row -text [Tick [IsLocal $type $obj $method]]]
        ::tclook::Bind $v method [list $type $obj $method]
        grid $k $v $p $l -sticky ew
    }
}

proc ::tclook::namespace::Pane {w name} {
    set f [ttk::frame $w.f]
    set type namespace
    foreach key {name vars commands children} {
        if {$key eq "name"} {
            set vals [list $name]
        } elseif {$key in {vars commands}} {
            set vals [info $key $name\::*]
        } else {
            set vals [namespace $key $name]
        }
        incr row
        set val {}
        set k [ttk::label $f.k$row -text $key]
        set v [ttk::label $f.v$row -text $val]
        grid $k $v - - -sticky ew
        foreach val $vals {
            incr row
            set k [ttk::label $f.k$row]
            set v [ttk::label $f.v$row -text $val]
            switch $key {
                commands { ::tclook::Bind $v command $val}
                children { ::tclook::Bind $v namespace $val}
            }
            grid $k $v - - -sticky ew
        }
    }
    grid columnconfigure $f 1 -weight 1
    return $f
}

proc ::tclook::method::Pane {w data} {
    lassign $data ooc obj name
    set type method
    set f [ttk::frame $w.f]
    set key name
    set val $name
    incr row
    set k [ttk::label $f.k$row -text $key]
    set v [ttk::label $f.v$row -text $val]
    grid $k $v - - -sticky ew
    lassign [info $ooc definition $obj $name] args body
    set key arguments
    set val $args
    incr row
    set k [ttk::label $f.k$row -text $key]
    set v [ttk::label $f.v$row -text $val]
    grid $k $v - - -sticky ew
    set key body
    set val $body
    incr row
    set k [ttk::label $f.k$row -text $key]
    set v [ttk::label $f.v$row -text $val]
    grid $k $v - - -sticky ew
    set key type
    set val [info $ooc methodtype $obj $name]
    incr row
    set k [ttk::label $f.k$row -text $key]
    set v [ttk::label $f.v$row -text $val]
    grid $k $v - - -sticky ew
    grid columnconfigure $f 1 -weight 1
    return $f
}

proc ::tclook::command::Pane {w name} {
    if no {
        tk_messageBox -message [info level 0]
    }
    set type command
    set f [ttk::frame $w.f]
    set key name
    set val $name
    incr row
    set k [ttk::label $f.k$row -text $key]
    set v [ttk::label $f.v$row -text $val]
    grid $k $v - - -sticky ew
    lassign  args body
    set key arguments
    set val [info args $name]
    incr row
    set k [ttk::label $f.k$row -text $key]
    set v [ttk::label $f.v$row -text $val]
    grid $k $v - - -sticky ew
    set key body
    set val [info body $name]
    incr row
    set k [ttk::label $f.k$row -text $key]
    set v [ttk::label $f.v$row -text $val]
    grid $k $v - - -sticky ew
    grid columnconfigure $f 1 -weight 1
    return $f
}

proc ::tclook::Bind {w {label wobj} {data {}} {cursor hand2}} {
    if {$label in {method namespace command}} {
        bind $w <1> [list ::tclook::_show $label $data]
        $w config -cursor hand2
    } else {
        bindtags $w [linsert [bindtags $w] 0 ${label}Popup]
        $w config -cursor $cursor
    }
}

proc ::tclook::Tick val {
    expr {$val ? "\u2713" : ""}
}

proc ::tclook::IsPrivate {type obj m} {
    expr {$m ni [info $type methods $obj -all]}
}

proc ::tclook::IsLocal {type obj m} {
    expr {$m in [info $type methods $obj -private]}
}

proc ::tclook::NewWindow {} {
    variable wn
    toplevel .t[incr wn]
}

return

proc ::tclook::GetDict obj {
    set result {}
    set obj [uplevel 1 [list namespace which -command $obj]]
    dict set result object name $obj
    array set isa [concat {*}[lmap i {class metaclass object} {
        list $i [info object isa $i $obj]
    }]]
    dict set result object isa [dict keys [dict filter [array get isa] value 1]]
    # TODO decide about other subcommands
    set type class
    if {$isa($type)} {
        foreach subcmd {superclasses mixins filters variables instances} {
            dict set result $type $subcmd [info $type $subcmd $obj]
        }
        set methods [lsort -dictionary [info $type methods $obj -private -all]]
        foreach method $methods {
            dict set result $type methods $method private [IsPrivate $type $obj $method]
            dict set result $type methods $method local [IsLocal $type $obj $method]
        }
    }
    set type object
    if {$isa($type)} {
        foreach subcmd {class mixins filters variables namespace vars} {
            dict set result $type $subcmd [info $type $subcmd $obj]
        }
        set methods [lsort -dictionary [info $type methods $obj -private -all]]
        foreach method $methods {
            dict set result $type methods $method private [IsPrivate $type $obj $method]
            dict set result $type methods $method local [IsLocal $type $obj $method]
        }
    }
    return $result
}
