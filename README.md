# odin-libgc
This is a simple library wrapper for libgc, providing garbage collection to the Odin programming language.

```odin
package main

import "gc"
import "core:fmt"

main :: proc() {
    // Initialize the collector and set the main context.
    // All allocations are now handled by the garbage collector.
    context = gc.initialize()
    
    // The GC string functions always uses the atomic allocator.
    join := gc.sprint("Hello", "World")
    fmt.println(join)

    // fmt.a* functions will use standard GC allocator in this case.
    str := fmt.aprint("foo", "bar")
    fmt.println(str)
}
```