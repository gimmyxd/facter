# frozen_string_literal: true

require 'ruby-prof'
require 'facter'

# RubyProf::WALL_TIME
# Wall time measures the real-world time elapsed between any two moments in seconds.
# If there are other processes concurrently running on the system that use significant
# CPU or disk time during a profiling run then the reported results will be larger
# than expected. On Windows, wall time is measured using GetTickCount(),
# on MacOS by mach_absolute_time, on Linux by clock_gettime and otherwise by gettimeofday.

# RubyProf::PROCESS_TIME
# Process time measures the time used by a process between any two moments in seconds.
# It is unaffected by other processes concurrently running on the system.
# Remember with process time that calls to methods like sleep will not be included in profiling results.
# On Windows, process time is measured using GetProcessTimes and on other platforms by clock_gettime.

# RubyProf::ALLOCATIONS
# Object allocations measures show how many objects each method in a program allocates.
# Measurements are done via Ruby's GC.stat api.

# RubyProf::MEMORY
# Memory measures how much memory each method in a program uses in bytes.
# Measurements are done via Ruby's TracePoint api.
RubyProf.measure_mode = RubyProf::WALL_TIME

profile = RubyProf::Profile.new
profile.start
Facter.to_hash
result = profile.stop
printer = RubyProf::MultiPrinter.new(result)
printer.print(path: 'benchmarks/output', profile: "profile.#{Time.now.to_f}", min_percent: 0.1)
