# phyzig

My attempt at 3D physics. created to better utilize threading and cache
coherency, as well as improve cross-platform support. All of these are in
comparison to ODE, a physics engine which I did not have a great experience
with.

## Planned Features

- C API!
- Easy serialization of physics state to disk
- Multithreading
- Generic over allocation (ie. the API allows you to pass in an allocator)
- Compile-time-known collision handlers for platforms where code size is not
  a concern. And probably requiring that you use Zig. And also it only really
  makes sense if you have a large pool of things all with the same collision
  handler and want them to be grouped together. So maybe just function pointers?
- Maybe one day support for GPU acceleration via Vulkan compute shaders?

## Goals

- Reliability in general, and in cases of failure, graceful failure
- Speed
- NOT memory usage. Speed will always come before memory usage.
