oo::class create AssertionHandler {
    constructor args {
        if {[lindex $args 0] eq "-useassertions"} {
            set args [lrange $args 1 end]
            oo::objdefine [self] forward assert my Assert
        } else {
            oo::objdefine [self] method assert args {}
        }
        next {*}$args
    }

    method Assert expr {
        if {![uplevel 1 [list expr $expr]]} {
            return -code error "Assertion failed: $expr"
        }
    }

}
