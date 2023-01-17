package main

import "core:fmt"
import "gc"

main :: proc() {
    gc.initialize()
    
    join := gc.sprint("Hello", "World")
    fmt.println(join)

    {
        context.allocator = gc.allocator
        str := fmt.aprint("foo", "bar")
        fmt.println(str)
    }

    bytes := gc.malloc(16)
    fmt.println("Raw pointer", bytes)
}