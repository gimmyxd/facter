# Benchmarking facter code

```
bundle exec ruby benchmarks/profiler.rb
```

This will generate 2 profiling files

- profile.flat.txt -> The flat report show the overall time spent in each method. Its is a good way of quickly identifying which methods take the most time

- profile.graph.html -> HTML Graph profiles are the same as graph reports, except output is generated in hyper-linked HTML. Since graph reports can be quite large, the embedded links make it much easier to navigate the results.
