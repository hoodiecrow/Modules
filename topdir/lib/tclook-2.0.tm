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

proc ::tclook::Init {} {
    variable tree {}
    variable top .tclook
    destroy $top
    toplevel $top
    grid [ttk::treeview $top.tv -show tree -yscroll [list $top.v set]] [ttk::scrollbar $top.vs -orient vertical -command [list $top.tv yview]] -sticky news
    set bigfont [font create]
    font configure $bigfont {*}[font actual TkDefaultFont]
    font configure $bigfont -weight bold -size 10
    $top.tv tag configure big -font $bigfont
    bind $top.tv <<TreeviewSelect>> {
        set i [%W focus]
        set p [%W parent $i]
        if {[llength $p] eq 2} {
            set v [%W item $i -text]
            switch [lindex $p end] {
                methods { ::tclook::show [lindex $v 0] [lrange $v 1 end] }
                namespace { puts "show namespace $v" }
                class -
                superclasses -
                subclasses -
                mixins { ::tclook::show class $v }
                instances {
                    if {[info object isa class $v]} {
                        ::tclook::show class $v
                    } else {
                        ::tclook::show object $v
                    }
                }
                default {
                    puts WHAT
                }
            }
        }
    }
}

proc ::tclook::show {{type class} {desc ::oo::class}} {
    log::log d [info level 0] 
    # TODO $desc doesn't need [list] in most cases
    variable top
    set tv $top.tv
    set _desc [uplevel 1 [list namespace which $desc]]
    if {$_desc ne {}} {
        set desc $_desc
    }
    if no {
        if {![$tv exists [list $desc]]} {
            switch $type {
                object { set values [GetValues object $desc methods namespace class mixins] }
                class { set values [GetValues class $desc methods superclasses subclasses mixins instances] }
                method {
                    ShowMethod {*}$desc
                    return
                }
                default {
                    ;
                }
            }
            $tv insert {} end -id [list $desc] -text $desc
            $tv tag add big [list $desc]
            dict for {key items} $values {
                if {![$tv exists $key]} {
                    $tv insert [list $desc] end -id [list $desc $key] -text [string totitle $key]
                    foreach item $items {
                        $tv insert [list $desc $key] end -text $item
                    }
                }
            }
        }
        $tv see [list $desc]
    }
    if {![$tv exists $desc]} {
        switch $type {
            object { set values [GetValues object $desc methods namespace class mixins] }
            class { set values [GetValues class $desc methods superclasses subclasses mixins instances] }
            method {
                ShowMethod {*}$desc
                return
            }
            default {
                ;
            }
        }
        $tv insert {} end -id $desc -text $desc
        $tv tag add big $desc
        dict for {key items} $values {
            if {![$tv exists $key]} {
                $tv insert $desc end -id [list $desc $key] -text [string totitle $key]
                foreach item $items {
                    $tv insert [list $desc $key] end -text $item
                }
            }
        }
    }
    $tv see $desc
}

proc ::tclook::ShowMethod {name arglist class} {
    tk_messageBox -message [list method $name {*}[info class definition $class $name]]
}

proc ::tclook::GetValues {type id args} {
    foreach key $args {
        dict set values $key [switch $key {
            methods      { GetMethods $type $id }
            namespace    { info $type $key $id }
            class        { info $type $key $id }
            superclasses { info $type $key $id }
            subclasses   { info $type $key $id }
            mixins       -
            instances    { info $type $key $id }
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
