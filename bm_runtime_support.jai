// Minimum viable Runtime_Support.
// Contains code the compiler expects to exist.

// Required parameters, can be unused.
#module_parameters(
    DEFINE_SYSTEM_ENTRY_POINT: bool,
    DEFINE_INITIALIZATION:     bool,
    ENABLE_BACKTRACE_ON_CRASH: bool
);

// This is the only declaration Runtime_Support must export.
#scope_export Context_Base :: struct {
    // The names of these fields should not change.
    // Changing them will cause compilation to fail at random.

    context_info: *void;
    thread_index: u32;

    allocator := default_allocator;
    logger    := runtime_support_default_logger;

    logger_data:           *void;
    log_source_identifier: u64;
    log_level:             u8;

    temporary_storage: *void;
    stack_trace:       *void;

    assertion_failed           := runtime_support_assertion_failed;
    handling_assertion_failure := false;

    default_allocator :: Allocator.{runtime_support_default_allocator_proc, null};
}

// Below are procedures required to be defined by Runtime_Support.
// If any are missing, the compiler will crash.
#scope_file

runtime_support_assertion_failed :: (loc: Source_Code_Location, message: string) -> bool {
    c_puts("Assertion failed.");
    return true;
}

runtime_support_default_logger :: (message: string, data: *void, info: Log_Info) {
    data := c_malloc(message.count.(u64) + 1).(*u8);
    defer c_free(data);

    memset(data, 0, message.count + 1);
    memcpy(data, message.data, message.count);
    c_puts(data);
}

runtime_support_default_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
    if mode == {
        case .ALLOCATE;
            return c_malloc(requested_size.(u64));
        case .RESIZE;
            return c_realloc(old_memory, requested_size.(u64));
        case .FREE;
            c_free(old_memory);
    }

    return null;
}

__element_duplicate :: (start: *u8, num_elements: s64, size: s64) #c_call #no_aoc {
    cursor := start + size;
    for 1..num_elements-1 {
        memcpy(cursor, start, size);
        cursor += size;
    }
}

__array_bounds_check_fail :: (index: s64, limit: s64, line_number: s64, filename: *u8) #no_context {
    c_puts("Array bounds check failed.");
    panic();
}

__cast_bounds_check_fail :: (pre_value: s64, pre_flags: u32, post_value: s64, post_flags: u32, fatal: u8, line_number: s64, filename: *u8) #no_context {
    c_puts("Cast bounds check failed.");
    if fatal then panic();
}

__null_pointer_check_fail :: (index: s64, line_number: s64, filename: *u8) #no_context {
    c_puts("Null pointer check failed.");
    panic();
}

__arithmetic_overflow :: (left: s64, right: s64, type_code: u16, line_number: s64, filename: *u8) #no_context #no_aoc {
    fatal := type_code & 0x8000;
    c_puts("Arithmetic overflow.");
    if fatal then panic();
}

__panic_due_to_runtime_call_of_compile_time_procedure :: (line_number: s64, filename: *u8) #no_context {
    c_puts("Attempt to call a compile-time procedure at runtime.");
    panic();
}

// Unlike the others, this doesn't need to be declared. It is just a helper.
panic :: () #no_context {
    if #compile_time {
        compile_time_debug_break :: () #compiler #no_context;
        compile_time_debug_break();
    } else {
        #if OS == .PS5 {
            #asm { int 0x41; }
        } else #if OS == .OUNCE && CPU == .ARM64 {
           // udf 0x8002: 16 bit instruction (0x00, 16 bit immediate)
           #bytes .[0x02, 0x80, 0x00, 0x00];
        } else #if CPU == .X64 {
            #asm { int3; }
        } else #if CPU == .ARM64 {
            // BRK 0x01: 11 bit instruction, 16 bit immediate, 5 bit unused.
            #bytes .[0x20, 0x00, 0b001_0_0000, 0b1101_0100];
        } else #if OS == .WASM {
            wasm_debug_break :: () #foreign;
            wasm_debug_break();
        } else {
            llvm_trap :: () #intrinsic "llvm.debugtrap";
            llvm_trap();
        }
    }
}

// We are required to link against libc.
// Otherwise _memcpy, _memset, and _bzero will be missing at link-time.

#if OS == .WINDOWS {
    crt :: #library,system,link_always "msvcrt";
} else #if OS == .MACOS || OS == .IOS || OS == .LINUX || OS == .ANDROID {
    crt :: #library,system,link_always "libc";
} else #if OS == .PS5 {
    crt :: #library,system,no_dll,link_always "libc_stub_weak";
} else #if OS == .OUNCE {
    crt :: #library,system,link_always "nnSdk";
}

c_puts    :: (c: *u8)                            #foreign crt "puts";
c_malloc  :: (size: u64) -> *void                #foreign crt "malloc";
c_free    :: (memory: *void)                     #foreign crt "free";
c_realloc :: (memory: *void, size: u64) -> *void #foreign crt "realloc";
