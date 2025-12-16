// Minimum required entrypoint.
// Normally Runtime_Support declares a program entrypoint for us.
// However, that's been removed to show what's actually done.

#program_export "main"
__program_entrypoint :: (argc: s32, argv: **u8) -> s32 #c_call {
   // We need to initialize a default context for the Jai entrypoint.
   default_context: #Context;
   initializer_of(#Context)(*default_context);

   // Once the context is pushed, we can call the Jai entrypoint.
   push_context default_context {
      __program_main :: () #entry_point; // Maps to 'main' or whatever name we set in our build options.
      no_inline __program_main();
   }

   return 0;
}

main :: () {
   values: [..]string;
   append(*values, "hello");
   append(*values, "from");
   append(*values, "bare");
   append(*values, "metal");
   append(*values, "jai!");

   for values {
      c_puts(scope_freed_cstring(it));
   }
}

// . . .

append :: (arr: *[..]$T, value: T) {
   alloc := context.allocator;
   if arr.allocator.proc == null {
      arr.allocator = alloc;
   }

   if arr.allocated == 0 {
      arr.allocated = 8;
      arr.data      = alloc.proc(.ALLOCATE, arr.allocated * size_of(T), 0, null, alloc.data);
   }
   else if arr.count == arr.allocated {
      new_allocated := arr.allocated * 2;
      arr.data       = alloc.proc(.RESIZE, new_allocated * size_of(T), arr.allocated * size_of(T), arr.data, alloc.data);
      arr.allocated  = new_allocated;
   }

   #no_abc {
      arr.data[arr.count] = value;
   }

   arr.count += 1;
}

scope_freed_cstring :: (str: string) -> *u8 #expand {
   alloc := context.allocator;
   ptr   := alloc.proc(.ALLOCATE, str.count + 1, 0, null, alloc.data);
   `defer alloc.proc(.FREE, 0, 0, ptr, alloc.data);

   builtin_memset(ptr, 0, str.count + 1);
   memcpy(ptr, str.data, str.count);

   return ptr;
}

libc :: #library,system "libc";

c_puts    :: (str: *u8)           #foreign libc "puts";
c_malloc  :: (size: u64) -> *void #foreign libc "malloc";
c_free    :: (memory: *void)      #foreign libc "free";

builtin_memset :: (dest: *void, value: u8, count: s64) #intrinsic "memset";


