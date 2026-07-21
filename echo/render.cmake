include("${CMAKE_CURRENT_LIST_DIR}/verify.cmake")

# ============================================================================
# _render_all_module_names — every module name declared in a Modules table
# section, regardless of class (backs #include path-prefix recognition).
# ============================================================================

function(_render_all_module_names modules_section_prefix out_prefix)
    set(_render_count 0)
    set(_render_k 0)
    while(_render_k LESS ${modules_section_prefix}_row_total)
        if("${${modules_section_prefix}_row_${_render_k}_role}" STREQUAL "data")
            echo_table_require(${modules_section_prefix}_row_${_render_k} "module" _render_module_name)
            set(${out_prefix}_${_render_count} "${_render_module_name}" PARENT_SCOPE)
            math(EXPR _render_count "${_render_count}+1")
        endif()
        math(EXPR _render_k "${_render_k}+1")
    endwhile()
    set(${out_prefix}_total "${_render_count}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _render_module_class — one module name's declared class within a Modules
# table section, plus the file:line of that declaration row; out_found_var 0
# when the name is not declared there.
# ============================================================================

function(_render_module_class modules_section_prefix module_name out_found_var out_class_var out_file_var out_line_var)
    set(_render_found 0)
    set(_render_class "")
    set(_render_file "")
    set(_render_line "")
    set(_render_k 0)
    while(_render_k LESS ${modules_section_prefix}_row_total AND NOT _render_found)
        if("${${modules_section_prefix}_row_${_render_k}_role}" STREQUAL "data")
            echo_table_require(${modules_section_prefix}_row_${_render_k} "module" _render_row_name)
            if("${_render_row_name}" STREQUAL "${module_name}")
                echo_table_require(${modules_section_prefix}_row_${_render_k} "class" _render_class)
                set(_render_file "${${modules_section_prefix}_row_${_render_k}_file}")
                set(_render_line "${${modules_section_prefix}_row_${_render_k}_line}")
                set(_render_found 1)
            endif()
        endif()
        math(EXPR _render_k "${_render_k}+1")
    endwhile()
    set(${out_found_var} "${_render_found}" PARENT_SCOPE)
    set(${out_class_var} "${_render_class}" PARENT_SCOPE)
    set(${out_file_var} "${_render_file}" PARENT_SCOPE)
    set(${out_line_var} "${_render_line}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _render_extract_include_path — one already-stripped source line's #include
# argument, quoted or angled; out_found_var 0 when the line carries no
# include directive (or an unterminated one).
# ============================================================================

function(_render_extract_include_path stripped_line out_found_var out_path_var)
    set(_render_found 0)
    set(_render_path "")

    string(LENGTH "${stripped_line}" _render_line_len)
    string(LENGTH "#include" _render_directive_len)

    if(_render_line_len GREATER_EQUAL _render_directive_len)
        string(SUBSTRING "${stripped_line}" 0 ${_render_directive_len} _render_directive_probe)
        if(_render_directive_probe STREQUAL "#include")
            string(SUBSTRING "${stripped_line}" ${_render_directive_len} -1 _render_remainder)
            string(STRIP "${_render_remainder}" _render_remainder)
            string(LENGTH "${_render_remainder}" _render_remainder_len)
            if(_render_remainder_len GREATER 0)
                string(SUBSTRING "${_render_remainder}" 0 1 _render_open_char)
                set(_render_close_char "")
                if(_render_open_char STREQUAL "\"")
                    set(_render_close_char "\"")
                elseif(_render_open_char STREQUAL "<")
                    set(_render_close_char ">")
                endif()
                string(LENGTH "${_render_close_char}" _render_close_char_len)
                if(_render_close_char_len GREATER 0)
                    string(SUBSTRING "${_render_remainder}" 1 -1 _render_after_open)
                    string(FIND "${_render_after_open}" "${_render_close_char}" _render_close_pos)
                    if(NOT _render_close_pos EQUAL -1)
                        string(SUBSTRING "${_render_after_open}" 0 ${_render_close_pos} _render_path)
                        set(_render_found 1)
                    endif()
                endif()
            endif()
        endif()
    endif()

    set(${out_found_var} "${_render_found}" PARENT_SCOPE)
    set(${out_path_var} "${_render_path}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _render_path_module_prefix — the declared A-module name (per an all-classes
# name list) whose directory the given include path begins under, if any.
# ============================================================================

function(_render_path_module_prefix path names_prefix out_found_var out_module_var)
    set(_render_found 0)
    set(_render_module "")
    string(LENGTH "${path}" _render_path_len)

    set(_render_m 0)
    while(_render_m LESS ${names_prefix}_total AND NOT _render_found)
        set(_render_candidate "${${names_prefix}_${_render_m}}")
        set(_render_candidate_prefix "${_render_candidate}/")
        string(LENGTH "${_render_candidate_prefix}" _render_prefix_len)
        if(_render_path_len GREATER_EQUAL _render_prefix_len)
            string(SUBSTRING "${path}" 0 ${_render_prefix_len} _render_path_prefix)
            if(_render_path_prefix STREQUAL _render_candidate_prefix)
                set(_render_found 1)
                set(_render_module "${_render_candidate}")
            endif()
        endif()
        math(EXPR _render_m "${_render_m}+1")
    endwhile()

    set(${out_found_var} "${_render_found}" PARENT_SCOPE)
    set(${out_module_var} "${_render_module}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _render_collect_include_references — every #include directive, in every
# scoped text file, whose path begins under a declared A-module directory;
# indexed <out_prefix>_<n>_file / _line / _include / _module. Binary files
# carry no #include directives worth scanning and are skipped.
# ============================================================================

function(_render_collect_include_references root_a scoped_prefix names_prefix out_prefix)
    set(_render_count 0)

    set(_render_e 0)
    while(_render_e LESS ${scoped_prefix}_total)
        set(_render_relative_path "${${scoped_prefix}_${_render_e}}")
        set(_render_absolute_path "${root_a}/${_render_relative_path}")

        _verify_detect_binary("${_render_absolute_path}" _render_is_binary _render_content)

        if(NOT _render_is_binary)
            string(REPLACE "\r\n" "\n" _render_content "${_render_content}")
            _echo_split_lines("${_render_content}" _render_source_line _render_line_total)

            set(_render_n 0)
            while(_render_n LESS _render_line_total)
                math(EXPR _render_line_number "${_render_n}+1")
                string(STRIP "${_render_source_line_${_render_n}}" _render_stripped)

                _render_extract_include_path("${_render_stripped}" _render_has_include _render_include_path)
                if(_render_has_include)
                    _render_path_module_prefix("${_render_include_path}" "${names_prefix}" _render_has_module _render_include_module)
                    if(_render_has_module)
                        set(${out_prefix}_${_render_count}_file "${_render_relative_path}" PARENT_SCOPE)
                        set(${out_prefix}_${_render_count}_line "${_render_line_number}" PARENT_SCOPE)
                        set(${out_prefix}_${_render_count}_include "${_render_include_path}" PARENT_SCOPE)
                        set(${out_prefix}_${_render_count}_module "${_render_include_module}" PARENT_SCOPE)
                        math(EXPR _render_count "${_render_count}+1")
                    endif()
                endif()

                math(EXPR _render_n "${_render_n}+1")
            endwhile()
        endif()

        math(EXPR _render_e "${_render_e}+1")
    endwhile()

    set(${out_prefix}_total "${_render_count}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _render_dependency_gate — every collected include reference must resolve to
# a kernel-classed module within the render scope's target set: B's Modules
# table (transformed name) for a single-module render, A's Modules table
# (untransformed) for a full-kernel render. Collects every violation before
# reporting; zero files have been written by the time this runs.
# ============================================================================

function(_render_dependency_gate references_prefix single_module identity_a_prefix identity_b_prefix modules_a_section modules_b_section)
    set(_render_findings "")

    set(_render_r 0)
    while(_render_r LESS ${references_prefix}_total)
        set(_render_ref_file "${${references_prefix}_${_render_r}_file}")
        set(_render_ref_line "${${references_prefix}_${_render_r}_line}")
        set(_render_ref_include "${${references_prefix}_${_render_r}_include}")
        set(_render_ref_module "${${references_prefix}_${_render_r}_module}")

        set(_render_ref_ok 0)
        if(single_module)
            echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_render_ref_module}" _render_ref_target)
            _render_module_class("${modules_b_section}" "${_render_ref_target}" _render_ref_found _render_ref_class _render_ref_class_file _render_ref_class_line)
            if(_render_ref_found AND _render_ref_class STREQUAL "kernel")
                set(_render_ref_ok 1)
            endif()
            if(NOT _render_ref_ok)
                list(APPEND _render_findings "${_render_ref_file}:${_render_ref_line}: #include \"${_render_ref_include}\" -> module '${_render_ref_module}' transforms to '${_render_ref_target}', not kernel-classed in B's Modules table")
            endif()
        else()
            _render_module_class("${modules_a_section}" "${_render_ref_module}" _render_ref_found _render_ref_class _render_ref_class_file _render_ref_class_line)
            if(_render_ref_found AND _render_ref_class STREQUAL "kernel")
                set(_render_ref_ok 1)
            endif()
            if(NOT _render_ref_ok)
                list(APPEND _render_findings "${_render_ref_file}:${_render_ref_line}: #include \"${_render_ref_include}\" -> module '${_render_ref_module}', not kernel-classed in A's Modules table")
            endif()
        endif()

        math(EXPR _render_r "${_render_r}+1")
    endwhile()

    if(_render_findings)
        string(JOIN "\n" _render_message ${_render_findings})
        message(FATAL_ERROR "echo: render: dependency closure violated, zero files written:\n${_render_message}")
    endif()
endfunction()

# ============================================================================
# _render_stash_ignored_paths — every B-side file already on disk under a
# target module directory, whose repo-relative path matches B's own Sync
# Ignore patterns, copied into stash_root (mirroring its path relative to
# root_b) before that module directory is replaced; per-framework generated
# content living inside a kernel module directory survives a whole-module
# render.
# ============================================================================

function(_render_stash_ignored_paths root_b module_name_b pattern_b_prefix pattern_b_total stash_root)
    set(_render_module_dir "${root_b}/${module_name_b}")

    if(IS_DIRECTORY "${_render_module_dir}")
        file(GLOB_RECURSE _render_existing_files "${_render_module_dir}/*")

        foreach(_render_existing_file ${_render_existing_files})
            if(NOT IS_DIRECTORY "${_render_existing_file}")
                file(RELATIVE_PATH _render_existing_relative_path "${root_b}" "${_render_existing_file}")
                _verify_path_excluded("${pattern_b_prefix}" "${pattern_b_total}" "${_render_existing_relative_path}" _render_is_ignored)

                if(_render_is_ignored)
                    set(_render_stash_destination "${stash_root}/${_render_existing_relative_path}")
                    get_filename_component(_render_stash_destination_dir "${_render_stash_destination}" DIRECTORY)
                    file(MAKE_DIRECTORY "${_render_stash_destination_dir}")
                    file(COPY_FILE "${_render_existing_file}" "${_render_stash_destination}")
                endif()
            endif()
        endforeach()
    endif()
endfunction()

# ============================================================================
# _render_restore_stashed_paths — every file under stash_root copied back to
# its mirrored location under root_b, undoing _render_stash_ignored_paths
# after the module directory has been replaced.
# ============================================================================

function(_render_restore_stashed_paths stash_root root_b)
    if(IS_DIRECTORY "${stash_root}")
        file(GLOB_RECURSE _render_stashed_files "${stash_root}/*")

        foreach(_render_stashed_file ${_render_stashed_files})
            if(NOT IS_DIRECTORY "${_render_stashed_file}")
                file(RELATIVE_PATH _render_stashed_relative_path "${stash_root}" "${_render_stashed_file}")
                set(_render_restore_destination "${root_b}/${_render_stashed_relative_path}")
                get_filename_component(_render_restore_destination_dir "${_render_restore_destination}" DIRECTORY)
                file(MAKE_DIRECTORY "${_render_restore_destination_dir}")
                file(COPY_FILE "${_render_stashed_file}" "${_render_restore_destination}")
            endif()
        endforeach()
    endif()
endfunction()

# ============================================================================
# Direct-invocation gate — same technique as diff.cmake's own gate, keyed to
# this file's name so the include() above never runs verify.cmake's block.
# ============================================================================

get_filename_component(_render_self_name "${CMAKE_CURRENT_LIST_FILE}" NAME)
set(_render_self_index -1)
set(_render_i 0)
while(_render_i LESS CMAKE_ARGC)
    get_filename_component(_render_argv_name "${CMAKE_ARGV${_render_i}}" NAME)
    if(_render_argv_name STREQUAL _render_self_name)
        set(_render_self_index ${_render_i})
    endif()
    math(EXPR _render_i "${_render_i}+1")
endwhile()

if(_render_self_index GREATER -1)
    include("${CMAKE_CURRENT_LIST_DIR}/echo.cmake")

    set(_render_user_arg_count 0)
    math(EXPR _render_user_arg_start "${_render_self_index}+1")
    set(_render_i ${_render_user_arg_start})
    while(_render_i LESS CMAKE_ARGC)
        if(_render_user_arg_count EQUAL 0)
            set(_render_name_a "${CMAKE_ARGV${_render_i}}")
        elseif(_render_user_arg_count EQUAL 1)
            set(_render_name_b "${CMAKE_ARGV${_render_i}}")
        elseif(_render_user_arg_count EQUAL 2)
            set(_render_module_arg "${CMAKE_ARGV${_render_i}}")
        endif()
        math(EXPR _render_user_arg_count "${_render_user_arg_count}+1")
        math(EXPR _render_i "${_render_i}+1")
    endwhile()

    if(NOT _render_user_arg_count EQUAL 2 AND NOT _render_user_arg_count EQUAL 3)
        message(FATAL_ERROR "usage: cmake -P render.cmake <frameworkNameOrPath-A> <frameworkNameOrPath-B> [module]\nA name containing '/' is treated as a literal root path instead of a frameworks.md registry lookup.")
    endif()

    set(_render_single_module 0)
    if(_render_user_arg_count EQUAL 3)
        set(_render_single_module 1)
    endif()

    _verify_resolve_root("${_render_name_a}" _render_root_a)
    _verify_resolve_root("${_render_name_b}" _render_root_b)

    echo_identity_load("${_render_root_a}/lexicon/identity.md" _render_identity_a)
    echo_identity_load("${_render_root_b}/lexicon/identity.md" _render_identity_b)

    echo_table_parse("${_render_root_a}/lexicon/identity.md" _render_doc_a)
    echo_table_section(_render_doc_a "Modules" _render_modules_a)
    echo_table_parse("${_render_root_b}/lexicon/identity.md" _render_doc_b)
    echo_table_section(_render_doc_b "Modules" _render_modules_b)

    if(_render_single_module)
        _render_module_class(_render_modules_a "${_render_module_arg}" _render_module_found _render_module_class_value _render_module_class_file _render_module_class_line)
        if(NOT _render_module_found)
            message(FATAL_ERROR "echo: render: module '${_render_module_arg}' not declared in ${_render_root_a}/lexicon/identity.md Modules table")
        endif()
        if(NOT _render_module_class_value STREQUAL "kernel")
            message(FATAL_ERROR "echo: render: ${_render_module_class_file}:${_render_module_class_line}: module '${_render_module_arg}' is class '${_render_module_class_value}', not kernel")
        endif()
        set(_render_target_modules_0 "${_render_module_arg}")
        set(_render_target_modules_total 1)
    else()
        _verify_kernel_modules(_render_modules_a _render_target_modules)
    endif()

    echo_table_section(_render_doc_a "Sync Ignore" _render_ignore_a)
    _verify_parse_ignore_patterns(_render_ignore_a _render_pattern_a)
    echo_table_section(_render_doc_b "Sync Ignore" _render_ignore_b)
    _verify_parse_ignore_patterns(_render_ignore_b _render_pattern_b)

    _verify_scoped_files("${_render_root_a}" _render_target_modules _render_pattern_a _render_scoped_a)

    _render_all_module_names(_render_modules_a _render_all_names_a)
    _render_collect_include_references("${_render_root_a}" _render_scoped_a _render_all_names_a _render_references)
    _render_dependency_gate(_render_references ${_render_single_module} _render_identity_a _render_identity_b _render_modules_a _render_modules_b)

    set(_render_staging_root "${_verify_temp_dir}/echo/render-staging")
    set(_render_ignore_stash_root "${_verify_temp_dir}/echo/render-ignore-stash")

    file(REMOVE_RECURSE "${_render_staging_root}")
    file(MAKE_DIRECTORY "${_render_staging_root}")
    file(REMOVE_RECURSE "${_render_ignore_stash_root}")
    file(MAKE_DIRECTORY "${_render_ignore_stash_root}")

    _verify_export_forward("${_render_root_a}" _render_scoped_a _render_identity_a _render_identity_b "${_render_staging_root}")

    set(_render_rendered_count 0)
    set(_render_t 0)
    while(_render_t LESS _render_target_modules_total)
        set(_render_module_name_a "${_render_target_modules_${_render_t}}")
        echo_tokens_forward(_render_identity_a _render_identity_b "${_render_module_name_a}" _render_module_name_b)

        _render_stash_ignored_paths("${_render_root_b}" "${_render_module_name_b}" _render_pattern_b "${_render_pattern_b_total}" "${_render_ignore_stash_root}")

        file(REMOVE_RECURSE "${_render_root_b}/${_render_module_name_b}")
        if(IS_DIRECTORY "${_render_staging_root}/${_render_module_name_b}")
            file(RENAME "${_render_staging_root}/${_render_module_name_b}" "${_render_root_b}/${_render_module_name_b}")
        endif()

        _render_restore_stashed_paths("${_render_ignore_stash_root}" "${_render_root_b}")

        math(EXPR _render_rendered_count "${_render_rendered_count}+1")
        math(EXPR _render_t "${_render_t}+1")
    endwhile()

    file(REMOVE_RECURSE "${_render_staging_root}")
    file(REMOVE_RECURSE "${_render_ignore_stash_root}")

    message(STATUS "✓ rendered ${_render_rendered_count} module(s), ${_render_scoped_a_total} file(s): ${_render_name_a} -> ${_render_name_b}")
endif()
