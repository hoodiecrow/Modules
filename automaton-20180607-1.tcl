
proc fixJumps items {
    set map {}
    set code {}
    set n 0
    foreach item $items {
        if {[string match *: $item]} {
            lappend map [string trimright $item :] $n
        } else {
            lappend code $item
            incr n
        }
    }
    string map $map $code
}

fixJumps {
            R {J1 *-1} R {J1 *-1} R P
            L
   a_loop:  L {J1 *-1} L {J1 *-1} R
            E
            R {J0 done}
            R {J1 *-1} R
   b_loop:  R
            {J0 a_loop}
            E
            R {J1 *-1} R {J1 *-1}
            P
            L {J1 *-1} L {J1 *-1} P
            {J1 b_loop}
            R
            {J0 a_loop}
            L {J1 *-1} L {J1 *-1} R
            E
            R {J0 done}
   done:    H
}

fixJumps {
            R {J1 *-1} R {J1 *-1} R P
            L
   a_loop:  L {J1 *-1} L {J1 *-1} R
            E
            R {J0 done}
            R {J1 *-1} R
   b_loop:  R
            {J0 a_loop}
            E
            R {J1 *-1} R {J1 *-1}
            P
            L {J1 *-1} L {J1 *-1} P
            {J1 b_loop}
            R
            {J0 a_loop}
            E
   done:    H
}

