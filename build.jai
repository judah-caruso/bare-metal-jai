// Minimum viable metaprogram.
// This is required to ensure we use our version of Runtime_Support.
#run {
   set_build_options_dc(.{ do_output = false });

   ws := compiler_create_workspace();
   defer compiler_destroy_workspace(ws);

   opts := get_build_options(ws);
   opts.runtime_support_definitions   = .OMIT;
   opts.runtime_storageless_type_info = true;
   opts.output_executable_name        = "bare-metal-jai";

   set_build_options(opts, ws);

   // This must be replaced by a real file, otherwise the compiler will hang (at least on mac)
   remap_import(ws, "*", "Runtime_Support", "BARE_METAL_RUNTIME_SUPPORT");

   // This is actually loaded relative to the compiler executable, so blocking/replacing it
   // import will not do anything. To *actually* replace Preload, a 'modules' directory needs to
   // exist two levels above the executable; that directory should contain minimal Preload.jai file.
   remap_import(ws, "*", "Preload", "");

   compiler_begin_intercept(ws, .SKIP_ALL);
   add_build_file("main.jai", ws);

   while true {
      msg := compiler_wait_for_message();
      if msg.kind == .COMPLETE break;
      if msg.kind == .ERROR    break;

      if msg.kind == .FAILED_IMPORT {
         fail := msg.(*Message_Failed_Import);
         if fail.target_module_name == {
            case "BARE_METAL_RUNTIME_SUPPORT";
               provide_import(ws, fail, .PATH_TO_FILE, "bm_runtime_support.jai");
         }
      }
   }

   compiler_end_intercept(ws);
}

// Like main.jai, this metaprogram does not require any modules so we duplicate the declarations we need.
// These types should not be modified.

Workspace :: s64;

Build_Options :: struct {
    Output_Type :: enum u8 {
        NO_OUTPUT       :: 0;
        EXECUTABLE      :: 1;
        DYNAMIC_LIBRARY :: 2;
        STATIC_LIBRARY  :: 3;
        OBJECT_FILE     :: 4;
    };
    Os_Version :: struct { // Currently only used for macOS and iOS
        major: u8;
        minor: u8;
    };

    output_type := Output_Type.EXECUTABLE;

    using Commonly_Propagated: struct {
        write_added_strings                 := true;
        runtime_storageless_type_info       := false;

        shorten_filenames_in_error_messages := false;
        use_visual_studio_message_format    := false;
        use_natvis_compatible_types         := false;

        minimum_os_version: Os_Version;

        lazy_foreign_function_lookups := false;
        disable_redzone               := false;

        enable_bytecode_inliner       := true;
        enable_bytecode_deduplication := true;
        stack_trace                   := true;
        use_ansi_color                := true;
        interactive_bytecode_debugger := false;
        debug_for_expansions          := false;
        enable_frame_pointers         := true;

        runtime_support_definitions: enum u8 {
            AUTO;
            ENTRY_POINT_AND_INIT;
            ONLY_INIT;
            OMIT;
        } = .AUTO;

        backtrace_on_crash:        enum u8 { OFF; ON; } = .ON;
        array_bounds_check:        enum u8 { OFF; ON; ALWAYS; }      = .ON;
        cast_bounds_check:         enum u8 { OFF; NONFATAL; FATAL; } = .FATAL;
        null_pointer_check:        enum u8 { OFF; ON; }              = .ON;
        arithmetic_overflow_check: enum u8 { OFF; NONFATAL; FATAL; } = .OFF;
        dead_code_elimination:     enum u8 { NONE; ALL; MODULES_ONLY; } = .MODULES_ONLY;

        max_bytecode_instructions_for_inlined_initializer: s32 = 8;
        context_size_max: s32 = 4096;

        prevent_compile_time_calls_from_runtime := false;

        info_flags: enum_flags u32 {
            POLYMORPH_MATCH       :: 0x1;
            POLYMORPH_DEDUPLICATE :: 0x2;
        }

        text_output_flags: enum_flags u32 {
            OUTPUT_LINK_LINE      :: 0x1;
            OUTPUT_TIMING_INFO    :: 0x2;
        } = xx 3;

        os_target  := OS;
        cpu_target := CPU;
        backend: enum u32 { X64; LLVM; } = .LLVM;

        machine_options: [MACHINE_OPTIONS_SIZE] u8;

        emit_debug_info: enum u32 {
            NONE       :: 0;
            DWARF      :: 1;
            CODEVIEW   :: 2;
            DEFAULT    :: 3;
        } = .DEFAULT;

        maximum_polymorph_depth := 100;
        maximum_array_count_before_compile_time_returns_are_not_reflected_in_ast := 5000;

        x64_options:  X64_Options;
        llvm_options: Llvm_Options;
    }

    output_executable_name:    string;
    output_path:               string;
    intermediate_path:         string;
    entry_point_name:          string;
    compile_time_command_line: []string;

    append_executable_filename_extension := true;
    use_custom_link_command              := false;

    temporary_storage_size: s32 = 32768;

    import_path:                 []string;
    additional_linker_arguments: []string;

    user_data_u64:          u64;
    user_data_string:       string;
    user_data_pointer:      *void;
    user_data_pointer_size: s32;
}

X64_Options :: struct {
    use_dlls := false;
    enable_register_allocation := false;
    enable_unix_runtime_frame_information := true;
}

Llvm_Options :: struct {
    bitcode_optimization_setting: enum u8 {
       UNSET :: 0;
       O0    :: 1;
       O1    :: 2;
       O2    :: 3;
       O3    :: 4;
       OS    :: 5;
       OZ    :: 6;
    };

    machine_code_optimization_setting: enum u8 {
       UNSET      :: 0;
       NONE       :: 1;
       LESS       :: 2;
       DEFAULT    :: 3;
       AGGRESSIVE :: 4;
    };

    function_sections: bool = false;

    enable_tail_calls         := false;
    enable_loop_unrolling     := false;
    enable_slp_vectorization  := false;
    enable_loop_vectorization := false;

    preserve_debug_info       := true;

    merge_functions  := false;
    disable_inlining := true;
    disable_mem2reg  := false;

    enable_split_modules := true;

    output_bitcode_before_optimizations := false;
    output_llvm_ir_before_optimizations := false;

    output_bitcode := false;
    output_llvm_ir := false;

    target_system_triple:   string;
    target_system_cpu:      string;
    target_system_features: string;

    command_line: []string;
}

Build_Options_During_Compile :: struct {
    do_output                            := true;
    write_added_strings                  := true;
    append_executable_filename_extension := true;
    interactive_bytecode_debugger        := false;

    append_linker_arguments: []string;
    output_executable_name:  string;
    output_path:             string;
}

Message :: struct {
    kind : enum u8 {
        UNINITIALIZED :: 0;
        FILE;
        IMPORT;
        FAILED_IMPORT;
        PHASE;
        TYPECHECKED;
        COMPLETE;
        DEBUG_DUMP;
        ERROR;
        PERFORMANCE_REPORT;
    }

    workspace: Workspace;
}

Message_Failed_Import :: struct {
    #as using m : Message;

    status: enum u8 {
        UNINITIALIZED :: 0;
        BLOCKED       :: 1;
        NOT_FOUND     :: 2;
    };

    host_module_name:       string;
    target_module_name:     string;

    import_code: *void;
}

Intercept_Flags :: enum_flags u32 {
    SKIP_EXPRESSIONS_WITHOUT_NOTES :: 0x1;
    SKIP_DECLARATIONS              :: 0x2;
    SKIP_PROCEDURE_HEADERS         :: 0x4;
    SKIP_PROCEDURE_BODIES          :: 0x8;
    SKIP_STRUCTS                   :: 0x10;
    SKIP_OTHERS                    :: 0x20;
    SKIP_ALL                       :: SKIP_EXPRESSIONS_WITHOUT_NOTES | SKIP_DECLARATIONS | SKIP_PROCEDURE_HEADERS | SKIP_PROCEDURE_BODIES | SKIP_STRUCTS | SKIP_OTHERS;
    DO_PERFORMANCE_REPORT_POLYMORPHS :: 0x1000;
    DO_PERFORMANCE_REPORT_RUNS       :: 0x2000;
}

Provided_Import_Type :: enum u8 {
    SHORT_NAME        :: 0;
    PATH_TO_FILE      :: 1;
    PATH_TO_DIRECTORY :: 2;
    FULL_TEXT         :: 3;
}

set_build_options_dc       :: (options: Build_Options_During_Compile, w: Workspace = -1) #compiler;
compiler_create_workspace  :: (name := "") -> Workspace #compiler;
compiler_destroy_workspace :: (w: Workspace) #compiler;
get_build_options          :: (w: Workspace = -1) -> Build_Options #compiler;
compiler_begin_intercept   :: (w: Workspace, flags: Intercept_Flags = 0) #compiler;
compiler_end_intercept     :: (w: Workspace) #compiler;
compiler_wait_for_message  :: () -> *Message #compiler;
set_build_options          :: (options: Build_Options, w: Workspace = -1, loc := #caller_location) #compiler;
remap_import               :: (w: Workspace, host_module_name: string, import_name: string, replacement_name: string) #compiler;
provide_import             :: (w: Workspace, message: *Message_Failed_Import, type: Provided_Import_Type, value: string) #compiler;
add_build_file             :: (filename: string, w: Workspace, loc := #caller_location) #compiler;
