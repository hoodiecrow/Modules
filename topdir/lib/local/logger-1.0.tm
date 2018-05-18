package require log

oo::class create Logger {
    forward Warn my Log warning
    forward Note my Log notice
    forward Info my Log info
    method Error msg {
        log::log d [info level 0] 
        my Log error $msg
        return -code error [format {Error: %s} $msg]
    }
    method Assert {cond {msg {}} args} {
        if {![uplevel 1 [list expr $cond]]} {
            set prefix [lindex [info level -1] 1]
            if {$msg eq {}} {
                my Error [format {%s: assertion failed: %s} $prefix $cond]
            } else {
                my Error [format {%s: %s} $prefix [format $msg {*}$args]]
            }
        }
    }
    method Ensure {cond msg args} {
        log::log d [info level 0] 
        if {![uplevel 1 [list expr $cond]]} {
            my Error [format $msg {*}$args]
        }
    }
}

oo::class create Dump {
    mixin Logger
    variable dump
    method Reset args {set dump {} ; next {*}$args}
    method dump {} {set dump}
    method Log {level text} {lappend dump $text}

}

oo::class create Log {
    mixin Logger
    method Reset args {log::lvChannel error stdout ; next {*}$args}
    forward Log ::log::log
}

oo::class create NoLog {
    method Reset args {next {*}$args}
    foreach m {Log Warn Info Note Error Assert} {
        forward $m list
    }
    method Ensure {cond msg args} {
        if {![uplevel 1 [list expr $cond]]} {
            return -code error [format $msg {*}$args]
        }
    }
}
