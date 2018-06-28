
# code from http://wiki.tcl.tk/40640, by aspect (http://wiki.tcl.tk/21336)
# minor changes by me

namespace eval inspect {
    variable wn
}

proc ::inspect::inspect {obj} {
    set obj [uplevel 1 [list namespace which -command $obj]]
    set isa [lmap type {object class metaclass} {
        if {![info object isa $type $obj]} continue
        set type
    }]
    if {"class" in $isa} {
        foreach subcmd {superclasses mixins filters methods variables instances} {
            lappend queries [list class $subcmd]
        }
    }
    if {"object" in $isa} {
        foreach subcmd {class mixins filters methods variables namespace vars} {
            lappend queries [list object $subcmd]
        }
    }
    set result [dict create isa $isa]
    foreach query $queries {
        dict set result $query [info {*}$query $obj]
        if {[lindex $query 1] eq "methods"} {
            foreach opt {-private -all {-private -all}} {
                catch {
                    dict set result [list {*}$query {*}$opt] [info {*}$query $obj {*}$opt]
                }
            }
        }
    }
    dict filter $result value {?*}
}

proc ::inspect::pdict {d {pattern *}} {   ;# analogous to parray
    set maxl [::tcl::mathfunc::max {*}[lmap key [dict keys $d] {string length $key}]]
    dict for {key value} [dict filter $d key $pattern] {
        puts stdout [format "%-*s = %s" $maxl $key $value]
    }
}

proc ::inspect::pobj {obj {pattern *}} {
    pdict [inspect $obj] $pattern
}

proc ::inspect::wobj {obj {pattern *}} {
    package require Tk
    variable wn
    set t [toplevel .t[incr wn]]
    set d [dict filter [inspect $obj] key $pattern]
    dict for {key value} [dict filter $d key $pattern] {
        if {[lindex $key 1] ne "methods"} {
            grid [ttk::label $t.k[incr row] -text $key] [ttk::label $t.v$row -text $value] -sticky ew
        }
    }
    grid [set fm [ttk::frame $t.fm]] - -sticky ew
    grid [ttk::label $fm.k[incr row] -text "class methods"] - - -sticky ew
    grid [ttk::label $fm.k[incr row] -text "method"] [ttk::label $fm.a$row -text "access"] [ttk::label $fm.o$row -text "origin"] -sticky ew
    foreach m [lsort -dictionary [info class methods $obj -private -all]] {
        grid [ttk::label $fm.k[incr row] -text $m] \
            [ttk::label $fm.a$row -text [if {[IsPrivate class $obj $m]} {format private}]] \
            [ttk::label $fm.o$row -text [if {![IsLocal class $obj $m]} {format inherited}]] -sticky ew
    }
    grid [ttk::label $fm.k[incr row] -text "object methods"] - - -sticky ew
    grid [ttk::label $fm.k[incr row] -text "method"] [ttk::label $fm.a$row -text "access"] [ttk::label $fm.o$row -text "origin"] -sticky ew
    foreach m [lsort -dictionary [info object methods $obj -private -all]] {
        grid [ttk::label $fm.k[incr row] -text $m] \
            [ttk::label $fm.a$row -text [if {[IsPrivate object $obj $m]} {format private}]] \
            [ttk::label $fm.o$row -text [if {![IsLocal object $obj $m]} {format inherited}]] -sticky ew
    }
}

proc ::inspect::IsPrivate {type obj m} {
    expr {$m ni [info $type methods $obj -all]}
}

proc ::inspect::IsLocal {type obj m} {
    expr {$m in [info $type methods $obj -private]}
}

