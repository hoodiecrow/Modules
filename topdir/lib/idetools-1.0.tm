
namespace eval idetools {}

proc ::idetools::testCommands dir {
    set auto_path [linsert $::auto_path 0 $dir]

    package require log

    proc ::log::listStack {{level d} {str "Listing stack\n"}} {
        set result {}
        for {set level 1} {$level < [info level]} {incr level} {
            lappend result "#$level [info level $level]"
        }
        log::log $level $str[join [lreverse $result] \n]
    }
}

proc ::idetools::runTests testdir {
    package require tcltest

    set outfile [file join $testdir testreport.txt]
    set errfile [file join $testdir testerrors.txt]
    file delete -force $outfile $errfile

    lappend ::argv -testdir $testdir
    lappend ::argv -outfile $outfile
    lappend ::argv -errfile $errfile
    lappend ::argv -tmpdir [file join $testdir temp]
    lappend ::argv -loadfile [file join $testdir common.tcl]

    uplevel #0 {
        ::tcltest::configure {*}$::argv

        ::tcltest::runAllTests
    }
}

proc ::idetools::buildStarkit project {
    set STARKITS [file normalize ~/starkits]
    exec tclsh [file join $STARKITS sdx.kit] wrap [file join $STARKITS $project.kit] -vfs ~/code/$project/topdir
} 
