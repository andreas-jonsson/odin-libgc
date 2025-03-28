// Basic Odin wrapper for libgc
// Updated: 2025-03-28, Andreas T Jonsson <mail@andreasjonsson.se>

package gc

import "core:testing"

// TODO: Add real tests.

@(test)
test_init :: proc(_: ^testing.T) {
	initialize()
}

@(test)
test_simple :: proc(_: ^testing.T) {
	initialize()
	sprint("Hello", "World")
	collect()
}

@(test)
test_free :: proc(_: ^testing.T) {
	initialize()
	ptr := malloc(16)
	collect()
	free(ptr)
	collect()
}

@(test)
test_incremental :: proc(_: ^testing.T) {
	initialize(true)
	for i in 0 ..< 1024 {
		array: [dynamic]rawptr
		for j in 0 ..< 1024 {
			append(&array, malloc(1024))
		}
	}
}

