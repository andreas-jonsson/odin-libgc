package main

import "core:fmt"
import "gc"

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

	bytes := gc.malloc(16)
	fmt.println("Raw pointer", bytes)

	fmt.print("Lots of allocations")
	for i in 0 ..< 100 {
		// Allocate 1Gb in 1Mb blocks.
		array: [dynamic]rawptr
		for j in 0 ..< 1024 {
			append(&array, gc.malloc(1024 * 1024))
		}
		fmt.print(".")
	}
	fmt.print("\n")
}
