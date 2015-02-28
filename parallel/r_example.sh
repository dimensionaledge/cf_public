#!/usr/bin/bash
unset R_HOME

fn_worker() {
R < process.R --vanila --slave --args $1
}
export -f fn_worker

seq 1 100 | parallel fn_worker {1}
