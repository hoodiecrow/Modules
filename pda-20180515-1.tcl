
trace add variable command write {apply {{a b c} {puts \$command=$::command}}}
trace add variable contexts write {apply {{a b c} {puts \$contexts=$::contexts}}}

proc init {} {
    global word command commands contexts results
    lassign {} word command commands contexts
}

proc add {str args} {
    appendWord $str
    uplevel 1 $args
}

proc beginWord args {
    global word
    set word {}
}

proc appendWord {str args} {
    global word
    append word $str
}

proc endWord args {
    global word
    return $word
}

proc beginCommand args {
    global command
    set command {}
    beginWord
}

proc endCommand args {
    global command
    set w [endWord]
    if {$w ne {}} {
        lappend command $w
    }
    appendContext $command
}

proc command args {
    global word command contexts
    endCommand
    beginCommand
    uplevel 1 $args
}

proc enter {str args} {
    beginContext $str
    uplevel 1 $args
}

proc beginContext {str args} {
    # $str is the context type: SBCQ
    global contexts
    lappend contexts {}
    beginCommand
}

proc appendContext cmd {
    global contexts
    set context [lindex $contexts end]
    set contexts [lrange $contexts 0 end-1]
    lappend context $cmd
    lappend contexts $context
}

proc endContext args {
    global contexts results
    endCommand
    lappend results [lindex $contexts end]
    set contexts [lrange $contexts 0 end-1]
}

proc leave args {
    endContext
    uplevel 1 $args
}

proc space args {
    endWord
    beginWord
    uplevel 1 $args
}

proc success str {
}

