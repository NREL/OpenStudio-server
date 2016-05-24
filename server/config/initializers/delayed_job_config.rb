# Allow the jobs to run for up to 1 week.  If this is ever hit, then we have
# other problems.
Delayed::Worker.max_run_time = 168.hours
