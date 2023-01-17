// Basic Odin wrapper for libgc
// Updated: 2023-01-17, Andreas T Jonsson <mail@andreasjonsson.se>

package gc

import "core:c"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:runtime"
import "core:testing"

when ODIN_OS == .Windows { foreign import gc "libgc.lib" }
when ODIN_OS != .Windows { foreign import gc "system:gc" }

warn_proc :: proc "c" (^c.char, c.ulong)

@(link_prefix="GC_")
@(default_calling_convention="c")
foreign gc {
	// Allocates and clears nbytes of storage. Requires (amortized) time proportional to nbytes.
	// The resulting object will be automatically deallocated when unreferenced.
	// References from objects allocated with the system malloc are usually not considered by the collector.
	// (See GC_MALLOC_UNCOLLECTABLE, however.) GC_MALLOC is a macro which invokes GC_malloc by default or,
	// if GC_DEBUG is defined before gc.h is included, a debugging version that checks occasionally for
	// overwrite errors, and the like. 
	malloc :: proc(size: c.size_t) -> rawptr ---
	
	// Allocates nbytes of storage. Requires (amortized) time proportional to nbytes.
	// The resulting object will be automatically deallocated when unreferenced.
	// The client promises that the resulting object will never contain any pointers.
	// The memory is not cleared. This is the preferred way to allocate strings, floating point arrays,
	// bitmaps, etc. More precise information about pointer locations can be communicated to the collector using
	// the interface in gc_typed.h in the distribution. 
	malloc_atomic :: proc(size: c.size_t) -> rawptr ---

	// Identical to GC_MALLOC, except that the resulting object is not automatically deallocated.
	// Unlike the system-provided malloc, the collector does scan the object for pointers to garbage-collectable memory,
	// even if the block itself does not appear to be reachable.
	// (Objects allocated in this way are effectively treated as roots by the collector.) 
	malloc_uncollectable :: proc(size: c.size_t) -> rawptr ---

	// Allocate a new object of the indicated size and copy (a prefix of) the old object into the new object.
	// The old object is reused in place if convenient. If the original object was allocated with GC_MALLOC_ATOMIC,
	// the new object is subject to the same constraints. If it was allocated as an uncollectable object,
	// then the new object is uncollectable, and the old object (if different) is deallocated. 
	realloc :: proc(ptr: rawptr, size: c.size_t) -> rawptr ---

	// Explicitly deallocate an object. Typically not useful for small collectable objects. 
	free :: proc(ptr: rawptr) ---

	// Explicitly force a garbage collection.
	gcollect :: proc() ---

	// Cause the garbage collector to perform a small amount of work every few invocations of GC_MALLOC or the like,
	// instead of performing an entire collection at once. This is likely to increase total running time.
	// It will improve response on a platform that either has suitable support in the garbage collector
	// (Linux and most Unix versions, win32 if the collector was suitably built) or if "stubborn" allocation is used (see gc.h).
	// On many platforms this interacts poorly with system calls that write to the garbage collected heap. 
	enable_incremental :: proc() ---

	// Replace the default procedure used by the collector to print warnings.
	// The collector may otherwise write to sterr, most commonly because GC_malloc was used in a situation in
	// which GC_malloc_ignore_off_page would have been more appropriate. See gc.h for details.
	// (In Odin logging is ALWAYS disabled by default.)
	set_warn_proc :: proc(p: warn_proc) -> warn_proc ---
}

@(private)
foreign gc {
	// TODO: We might need to replace this call with the GC_INIT macro on some platforms. :(
	GC_init :: proc "c" () ---
}

@(private)
do_alloc :: proc(mode: runtime.Allocator_Mode, size, alignment: int, old_memory: rawptr, $func: proc "c" (size: c.size_t) -> rawptr) -> ([]u8, runtime.Allocator_Error) {
	if alignment > size_of(rawptr) {
		return nil, .Invalid_Argument
	}

	#partial switch mode {
		case .Alloc, .Alloc_Non_Zeroed:
			p := func(c.size_t(size))
			if p == nil {
				return nil, .Out_Of_Memory
			}
			return slice.bytes_from_ptr(p, size), .None
		case .Free:
			free(old_memory)
			return nil, .None
		case .Free_All:
			gcollect()
			return nil, .None
		case .Resize:
			p := realloc(old_memory, c.size_t(size))
			if p == nil {
				return nil, .Out_Of_Memory
			}
			return slice.bytes_from_ptr(p, size), .None
	}
	return nil, .Mode_Not_Implemented
}

// This is the default allocator. The resulting object will be automatically deallocated when unreferenced.
// References from objects allocated with the system malloc are usually not considered by the collector.
allocator :: mem.Allocator{ procedure = proc(allocator_data: rawptr, mode: runtime.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> ([]u8, runtime.Allocator_Error) {
	return do_alloc(mode, size, alignment, old_memory, malloc)
}}

// The resulting object will be automatically deallocated when unreferenced.
// The client promises that the resulting object will never contain any pointers.
// The memory is not cleared. This is the preferred way to allocate strings, floating point arrays, bitmaps, etc.
atomic_allocator :: mem.Allocator{ procedure = proc(allocator_data: rawptr, mode: runtime.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> ([]u8, runtime.Allocator_Error) {
	return do_alloc(mode, size, alignment, old_memory, malloc_atomic)
}}

// Identical to "allocator", except that the resulting object is not automatically deallocated.
// Unlike the system-provided malloc, the collector does scan the object for pointers to garbage-collectable memory,
// even if the block itself does not appear to be reachable.
// (Objects allocated in this way are effectively treated as roots by the collector.)
uncollectable_allocator :: mem.Allocator{ procedure = proc(allocator_data: rawptr, mode: runtime.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> ([]u8, runtime.Allocator_Error) {
	return do_alloc(mode, size, alignment, old_memory, malloc_uncollectable)
}}

// On some platforms, it is necessary to invoke this from the main executable,
// not from a dynamic library, before the initial invocation of a GC routine.
initialize :: proc() {
	GC_init()
	set_warn_proc(proc "c" (^c.char, c.ulong) {}) // Disable logging by default
}

sprint :: proc(args: ..any, sep: string = " ") -> string {
	context.allocator = atomic_allocator
	return fmt.aprint(..args) // TODO: Fix sep?
}

sprintln :: proc(args: ..any, sep: string = " ") -> string {
	context.allocator = atomic_allocator
	return fmt.aprintln(..args) // TODO: Fix sep?
}

sprintf :: proc(format: string, args: ..any) -> string {
	context.allocator = atomic_allocator
	return fmt.aprintf(format, ..args)
}

// TODO: Add real tests.

@(test)
test_init :: proc(^testing.T) {
	initialize()
}

@(test)
test_simple :: proc(^testing.T) {
	initialize()
	sprint("Hello", "World")
	gcollect()
}

@(test)
test_free :: proc(^testing.T) {
    ptr := malloc(16)
	gcollect()
    free(ptr)
	gcollect()
}