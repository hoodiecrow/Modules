package require Tk
package require textutil::adjust
package require struct::matrix
package require Tktable

namespace eval tclook {}

# TclOO-based object/class/namespace browser

# 2018-07-16: show public interface only: non-private methods, no variables.
# Provide a combobox to query through 'info {*}[linsert $id 1 $subcmd]' for
# information beyond this; also make method names, class and instance names,
# and namespaces clickable.
# By default open into a notebook: views to be detachable.
# Extended view?

# NOTE filters are methods, so don't link them from the filters field

proc ::tclook::show {{type class} {desc ::oo::class}} {
    variable top
    set tv $top.tv
    set _desc [uplevel 1 [list namespace which $desc]]
    if {$_desc ne {}} {
        set desc $_desc
    }
    if {![$tv exists $desc]} {
        switch $type {
            object { set values [GetValues object $desc methods namespace class mixins] }
            class { set values [GetValues class $desc methods superclasses subclasses mixins instances] }
            namespace { set values [GetValues namespace $desc nsvars commands children] }
            method {
                ShowMethod {*}$desc
                return
            }
            command {
                ShowCommand $desc
                return
            }
            default {
                puts stderr [format {can't show %s %s} $type $desc]
                return
            }
        }
        $tv insert {} end -id $desc -text $desc
        $tv tag add big $desc
        dict for {key items} $values {
            $tv insert $desc end -id [list $desc $key] -text [string totitle $key]
            foreach item $items {
                $tv insert [list $desc $key] end -text $item
            }
        }
    }
    $tv see $desc
}

proc ::tclook::ShowMethod {name arglist class} {
    tk_messageBox -message [list method $name {*}[info class definition $class $name]]
}

proc ::tclook::ShowCommand name {
    catch { tk_messageBox -message [list proc $name [info args $name] [info body $name]] }
}

proc ::tclook::GetValues {type id args} {
    foreach key $args {
        dict set values $key [switch $key {
            methods      { GetMethods $type $id }
            namespace    -
            class        -
            superclasses -
            subclasses   -
            mixins       -
            instances    { info $type $key $id }
            nsvars       { info vars $id\::* }
            commands     { info commands $id\::* }
            children     { namespace children $id }
            default {
                ;
            }
        }]
    }
    return $values
}

proc ::tclook::GetMethods {type desc} {
    set result {}
    set methods [info $type methods $desc -all]
    foreach method $methods {
        set call [info $type call $desc $method]
        lassign [lindex $call 0] calltype methname definedat methimpl
        if {![string match ::oo::* $definedat]} {
            set signature {}
            lappend signature [info class methodtype $definedat $method]
            lappend signature $method
            lappend signature [lindex [info class definition $definedat $method] 0]
            lappend result [linsert $signature end $definedat]
        }
    }
    return $result
}

proc ::tclook::MakeView name {
    variable top $name
    destroy $top
    toplevel $top
    set tv [ttk::treeview $top.tv -show tree -yscroll [list $top.ys set]]
    set ys [ttk::scrollbar $top.ys -orient vertical -command [list $top.tv yview]]
    grid $tv $ys -sticky news
    grid columnconfigure $top $tv -weight 1
    grid rowconfigure $top $tv -weight 1
}

proc ::tclook::SetBigFont {} {
    variable top
    set bigfont [font create]
    font configure $bigfont {*}[font actual TkDefaultFont]
    font configure $bigfont -weight bold -size 10
    $top.tv tag configure big -font $bigfont
}

proc ::tclook::TreeviewSelect w {
    set item [$w focus]
    set parent [$w parent $item]
    if {[llength $parent] eq 2} {
        set value [$w item $item -text]
        switch [lindex $parent end] {
            methods { ::tclook::show [lindex $value 0] [lrange $value 1 end] }
            children -
            namespace { ::tclook::show namespace $value }
            commands { ::tclook::show command $value }
            class -
            superclasses -
            subclasses -
            mixins { ::tclook::show class $value }
            instances {
                if {[info object isa class $value]} {
                    ::tclook::show class $value
                } else {
                    ::tclook::show object $value
                }
            }
            default {
                puts WHAT
            }
        }
    }
}

proc ::tclook::Init {} {
    variable top
    MakeView .tclook
    SetBigFont
    bind $top.tv <<TreeviewSelect>> {::tclook::TreeviewSelect %W}
}

::tclook::Init

if {![info exists TCLOOK] || !$TCLOOK} {
    set TCLOOK 1
    package require log
    cd ~/code/Modules/
    tcl::tm::path add topdir/lib/
    ::log::lvSuppressLE i 0
    catch { package forget tclook } ; package require tclook
    source -encoding utf-8 automaton-20180628-2.tcl
    oo::class create Foo {method foo {a b} {list $b $a}}
    oo::class create Bar {superclass Foo ; method Qux {} {my foo m n} ; method quux {} {my foo x y}}
    Foo create foo
    Bar create bar
    ::tclook::show
}
