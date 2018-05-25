package require log

# TODO doesn't really work well currently.  Mixing in NoLog into
# the user class leaves Logger mixed in inside the instance.
# Mixing in NoLog in the instance constructor interferes with
# mixing in Log or Dump after construction.
# It helps leaving out mixin Logger inside NoLog.

oo::class create Logger {
    method Foo args {
        log::log d [self class]--[info level 0] 
    }
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
        if {![uplevel 1 [list expr $cond]]} {
            my Error [format $msg {*}$args]
        }
    }
}

oo::class create Dump {
    mixin Logger
    variable dump
    method Foo args {
        log::log d [self class]--[info level 0] 
    }
    method LogReset args {set dump {}}
    method dump {} {set dump}
    method Log {level text} {lappend dump $text}

}

oo::class create Log {
    mixin Logger
    method Foo args {
        log::log d [self class]--[info level 0] 
    }
    method LogReset args {log::lvChannel error stdout}
    forward Log ::log::log
}

oo::class create NoLog {
    method Foo args {
        log::log d [self class]--[info level 0] 
    }
    method LogReset args {}
    foreach m {Log Warn Info Note Error Assert} {
        forward $m list
    }
    method Ensure {cond msg args} {
        if {![uplevel 1 [list expr $cond]]} {
            return -code error [format $msg {*}$args]
        }
    }
}
