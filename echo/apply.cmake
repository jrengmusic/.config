include("${CMAKE_CURRENT_LIST_DIR}/verify.cmake")

# ============================================================================
# _apply_has_prefix / _apply_strip_prefix — literal prefix test and removal,
# backing the line classifier below (checked in most-specific-first order so
# a single-character content marker never shadows a longer structural
# prefix that happens to start with the same character).
# ============================================================================

function(_apply_has_prefix line prefix out_bool_var)
    string(LENGTH "${prefix}" _apply_prefix_len)
    string(LENGTH "${line}" _apply_line_len)
    set(_apply_has 0)
    if(_apply_line_len GREATER_EQUAL _apply_prefix_len)
        string(SUBSTRING "${line}" 0 ${_apply_prefix_len} _apply_probe)
        if(_apply_probe STREQUAL "${prefix}")
            set(_apply_has 1)
        endif()
    endif()
    set(${out_bool_var} "${_apply_has}" PARENT_SCOPE)
endfunction()

function(_apply_strip_prefix line prefix out_remainder_var)
    string(LENGTH "${prefix}" _apply_prefix_len)
    string(SUBSTRING "${line}" ${_apply_prefix_len} -1 _apply_remainder)
    set(${out_remainder_var} "${_apply_remainder}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _apply_path_in_scope — a repo-relative path begins under one of A's
# kernel module directories and is not matched by A's Sync Ignore patterns.
# ============================================================================

function(_apply_path_in_scope path kernel_a_prefix pattern_a_prefix out_in_scope_var)
    set(_apply_under_kernel 0)
    string(LENGTH "${path}" _apply_path_len)

    set(_apply_m 0)
    while(_apply_m LESS ${kernel_a_prefix}_total AND NOT _apply_under_kernel)
        set(_apply_candidate_prefix "${${kernel_a_prefix}_${_apply_m}}/")
        string(LENGTH "${_apply_candidate_prefix}" _apply_candidate_prefix_len)
        if(_apply_path_len GREATER_EQUAL _apply_candidate_prefix_len)
            string(SUBSTRING "${path}" 0 ${_apply_candidate_prefix_len} _apply_path_prefix)
            if(_apply_path_prefix STREQUAL _apply_candidate_prefix)
                set(_apply_under_kernel 1)
            endif()
        endif()
        math(EXPR _apply_m "${_apply_m}+1")
    endwhile()

    set(_apply_in_scope 0)
    if(_apply_under_kernel)
        _verify_path_excluded("${pattern_a_prefix}" "${${pattern_a_prefix}_total}" "${path}" _apply_is_excluded)
        if(NOT _apply_is_excluded)
            set(_apply_in_scope 1)
        endif()
    endif()

    set(${out_in_scope_var} "${_apply_in_scope}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _apply_transform_ab_or_devnull — one "a/<path>" / "b/<path>" / "/dev/null"
# token from a "Binary files ... differ" line; only the path portion of an
# a/ or b/ form is token-transformed, "/dev/null" passes through as-is.
# ============================================================================

function(_apply_transform_ab_or_devnull raw identity_a_prefix identity_b_prefix out_var)
    if(raw STREQUAL "/dev/null")
        set(${out_var} "/dev/null" PARENT_SCOPE)
    else()
        _apply_has_prefix("${raw}" "a/" _apply_ab_is_a)
        _apply_has_prefix("${raw}" "b/" _apply_ab_is_b)
        if(_apply_ab_is_a)
            _apply_strip_prefix("${raw}" "a/" _apply_ab_path)
            echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_apply_ab_path}" _apply_ab_trans)
            set(${out_var} "a/${_apply_ab_trans}" PARENT_SCOPE)
        elseif(_apply_ab_is_b)
            _apply_strip_prefix("${raw}" "b/" _apply_ab_path)
            echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_apply_ab_path}" _apply_ab_trans)
            set(${out_var} "b/${_apply_ab_trans}" PARENT_SCOPE)
        else()
            set(${out_var} "${raw}" PARENT_SCOPE)
        endif()
    endif()
endfunction()

# ============================================================================
# _apply_transform_diff — the unified-diff text from `git diff` in A's root,
# rewritten line by line into B's vocabulary. Scope is decided once per file,
# at that file's "diff --git a/<path> ..." header (A-side path against A's
# kernel modules + Sync Ignore); every other line belonging to that file is
# included only when that file was in scope, and every included line's path
# or content portion is token-transformed via echo_tokens_forward.
# ============================================================================

function(_apply_transform_diff diff_text identity_a_prefix identity_b_prefix kernel_a_prefix pattern_a_prefix out_content_var out_file_count_var)
    _verify_split_on_delimiter("${diff_text}" "\n" _apply_line_total)

    set(_apply_output "")
    set(_apply_in_scope 0)
    set(_apply_file_count 0)

    set(_apply_i 0)
    while(_apply_i LESS _apply_line_total)
        set(_apply_line "${_verify_part_${_apply_i}}")

        _apply_has_prefix("${_apply_line}" "diff --git a/" _apply_is_diffgit)
        _apply_has_prefix("${_apply_line}" "rename from " _apply_is_rename_from)
        _apply_has_prefix("${_apply_line}" "rename to " _apply_is_rename_to)
        _apply_has_prefix("${_apply_line}" "--- a/" _apply_is_old_path)
        _apply_has_prefix("${_apply_line}" "+++ b/" _apply_is_new_path)
        _apply_has_prefix("${_apply_line}" "Binary files " _apply_is_binary_line)
        _apply_has_prefix("${_apply_line}" "@@" _apply_is_hunk)

        if(_apply_is_diffgit)
            _apply_strip_prefix("${_apply_line}" "diff --git a/" _apply_remainder)
            string(FIND "${_apply_remainder}" " b/" _apply_b_pos)
            if(_apply_b_pos EQUAL -1)
                message(FATAL_ERROR "echo: apply: malformed diff header: ${_apply_line}")
            endif()
            string(SUBSTRING "${_apply_remainder}" 0 ${_apply_b_pos} _apply_path_a)
            math(EXPR _apply_b_start "${_apply_b_pos}+3")
            string(SUBSTRING "${_apply_remainder}" ${_apply_b_start} -1 _apply_path_b)

            _apply_path_in_scope("${_apply_path_a}" "${kernel_a_prefix}" "${pattern_a_prefix}" _apply_in_scope)

            if(_apply_in_scope)
                echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_apply_path_a}" _apply_trans_a)
                echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_apply_path_b}" _apply_trans_b)
                string(APPEND _apply_output "diff --git a/${_apply_trans_a} b/${_apply_trans_b}\n")
                math(EXPR _apply_file_count "${_apply_file_count}+1")
            endif()

        elseif(_apply_is_rename_from)
            if(_apply_in_scope)
                _apply_strip_prefix("${_apply_line}" "rename from " _apply_rename_path)
                echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_apply_rename_path}" _apply_trans_path)
                string(APPEND _apply_output "rename from ${_apply_trans_path}\n")
            endif()

        elseif(_apply_is_rename_to)
            if(_apply_in_scope)
                _apply_strip_prefix("${_apply_line}" "rename to " _apply_rename_path)
                echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_apply_rename_path}" _apply_trans_path)
                string(APPEND _apply_output "rename to ${_apply_trans_path}\n")
            endif()

        elseif(_apply_is_old_path)
            if(_apply_in_scope)
                _apply_strip_prefix("${_apply_line}" "--- a/" _apply_old_path)
                echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_apply_old_path}" _apply_trans_old)
                string(APPEND _apply_output "--- a/${_apply_trans_old}\n")
            endif()

        elseif(_apply_line STREQUAL "--- /dev/null")
            if(_apply_in_scope)
                string(APPEND _apply_output "--- /dev/null\n")
            endif()

        elseif(_apply_is_new_path)
            if(_apply_in_scope)
                _apply_strip_prefix("${_apply_line}" "+++ b/" _apply_new_path)
                echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_apply_new_path}" _apply_trans_new)
                string(APPEND _apply_output "+++ b/${_apply_trans_new}\n")
            endif()

        elseif(_apply_line STREQUAL "+++ /dev/null")
            if(_apply_in_scope)
                string(APPEND _apply_output "+++ /dev/null\n")
            endif()

        elseif(_apply_is_binary_line)
            if(_apply_in_scope)
                _apply_strip_prefix("${_apply_line}" "Binary files " _apply_binary_remainder)
                string(FIND "${_apply_binary_remainder}" " and " _apply_and_pos)
                if(_apply_and_pos EQUAL -1)
                    message(FATAL_ERROR "echo: apply: malformed binary files line: ${_apply_line}")
                endif()
                string(SUBSTRING "${_apply_binary_remainder}" 0 ${_apply_and_pos} _apply_binary_left)
                math(EXPR _apply_and_start "${_apply_and_pos}+5")
                string(SUBSTRING "${_apply_binary_remainder}" ${_apply_and_start} -1 _apply_binary_right_with_differ)

                string(LENGTH "${_apply_binary_right_with_differ}" _apply_bwd_len)
                math(EXPR _apply_differ_start "${_apply_bwd_len}-7")
                if(_apply_differ_start LESS 0)
                    message(FATAL_ERROR "echo: apply: malformed binary files line: ${_apply_line}")
                endif()
                string(SUBSTRING "${_apply_binary_right_with_differ}" ${_apply_differ_start} -1 _apply_differ_suffix_probe)
                if(NOT _apply_differ_suffix_probe STREQUAL " differ")
                    message(FATAL_ERROR "echo: apply: malformed binary files line: ${_apply_line}")
                endif()
                string(SUBSTRING "${_apply_binary_right_with_differ}" 0 ${_apply_differ_start} _apply_binary_right)

                _apply_transform_ab_or_devnull("${_apply_binary_left}" "${identity_a_prefix}" "${identity_b_prefix}" _apply_binary_left_trans)
                _apply_transform_ab_or_devnull("${_apply_binary_right}" "${identity_a_prefix}" "${identity_b_prefix}" _apply_binary_right_trans)

                string(APPEND _apply_output "Binary files ${_apply_binary_left_trans} and ${_apply_binary_right_trans} differ\n")
            endif()

        elseif(_apply_is_hunk)
            if(_apply_in_scope)
                string(APPEND _apply_output "${_apply_line}\n")
            endif()

        else()
            string(LENGTH "${_apply_line}" _apply_line_len)
            set(_apply_is_content 0)
            set(_apply_marker "")
            if(_apply_line_len GREATER 0)
                string(SUBSTRING "${_apply_line}" 0 1 _apply_first_char)
                if(_apply_first_char STREQUAL " " OR _apply_first_char STREQUAL "+" OR _apply_first_char STREQUAL "-")
                    set(_apply_is_content 1)
                    set(_apply_marker "${_apply_first_char}")
                endif()
            endif()

            if(_apply_is_content)
                if(_apply_in_scope)
                    string(SUBSTRING "${_apply_line}" 1 -1 _apply_content)
                    echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_apply_content}" _apply_trans_content)
                    string(APPEND _apply_output "${_apply_marker}${_apply_trans_content}\n")
                endif()
            else()
                if(_apply_in_scope)
                    string(APPEND _apply_output "${_apply_line}\n")
                endif()
            endif()
        endif()

        math(EXPR _apply_i "${_apply_i}+1")
    endwhile()

    set(${out_content_var} "${_apply_output}" PARENT_SCOPE)
    set(${out_file_count_var} "${_apply_file_count}" PARENT_SCOPE)
endfunction()

# ============================================================================
# Direct-invocation gate — same technique as verify.cmake's own gate, keyed
# to this file's name so the include() above never runs verify.cmake's
# comparison-verb block here.
# ============================================================================

get_filename_component(_apply_self_name "${CMAKE_CURRENT_LIST_FILE}" NAME)
set(_apply_self_index -1)
set(_apply_i 0)
while(_apply_i LESS CMAKE_ARGC)
    get_filename_component(_apply_argv_name "${CMAKE_ARGV${_apply_i}}" NAME)
    if(_apply_argv_name STREQUAL _apply_self_name)
        set(_apply_self_index ${_apply_i})
    endif()
    math(EXPR _apply_i "${_apply_i}+1")
endwhile()

if(_apply_self_index GREATER -1)
    include("${CMAKE_CURRENT_LIST_DIR}/echo.cmake")

    set(_apply_user_arg_count 0)
    set(_apply_diff_arg_total 0)
    math(EXPR _apply_user_arg_start "${_apply_self_index}+1")
    set(_apply_i ${_apply_user_arg_start})
    while(_apply_i LESS CMAKE_ARGC)
        if(_apply_user_arg_count EQUAL 0)
            set(_apply_name_a "${CMAKE_ARGV${_apply_i}}")
        elseif(_apply_user_arg_count EQUAL 1)
            set(_apply_name_b "${CMAKE_ARGV${_apply_i}}")
        else()
            list(APPEND _apply_diff_args "${CMAKE_ARGV${_apply_i}}")
            math(EXPR _apply_diff_arg_total "${_apply_diff_arg_total}+1")
        endif()
        math(EXPR _apply_user_arg_count "${_apply_user_arg_count}+1")
        math(EXPR _apply_i "${_apply_i}+1")
    endwhile()

    if(_apply_user_arg_count LESS 2)
        message(FATAL_ERROR "usage: cmake -P apply.cmake <frameworkNameOrPath-A> <frameworkNameOrPath-B> [git-diff-args...]\nA name containing '/' is treated as a literal root path instead of a frameworks.md registry lookup.")
    endif()

    _verify_resolve_root("${_apply_name_a}" _apply_root_a)
    _verify_resolve_root("${_apply_name_b}" _apply_root_b)

    echo_identity_load("${_apply_root_a}/lexicon/identity.md" _apply_identity_a)
    echo_identity_load("${_apply_root_b}/lexicon/identity.md" _apply_identity_b)

    echo_table_parse("${_apply_root_a}/lexicon/identity.md" _apply_doc_a)
    echo_table_section(_apply_doc_a "Modules" _apply_modules_a)
    _verify_kernel_modules(_apply_modules_a _apply_kernel_a)

    echo_table_section(_apply_doc_a "Sync Ignore" _apply_ignore_a)
    _verify_parse_ignore_patterns(_apply_ignore_a _apply_pattern_a)

    execute_process(
        COMMAND git diff ${_apply_diff_args}
        WORKING_DIRECTORY "${_apply_root_a}"
        OUTPUT_VARIABLE _apply_diff_output
        RESULT_VARIABLE _apply_diff_result
        ERROR_VARIABLE _apply_diff_error
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(NOT _apply_diff_result EQUAL 0)
        message(FATAL_ERROR "echo: apply: git diff failed in ${_apply_root_a}: ${_apply_diff_error}")
    endif()

    if(_apply_diff_output STREQUAL "")
        message(STATUS "✓ nothing to apply")
    else()
        _apply_transform_diff("${_apply_diff_output}" _apply_identity_a _apply_identity_b _apply_kernel_a _apply_pattern_a _apply_patch_content _apply_file_count)

        set(_apply_staging_root "${_verify_temp_dir}/echo/apply")
        file(REMOVE_RECURSE "${_apply_staging_root}")
        file(MAKE_DIRECTORY "${_apply_staging_root}")
        set(_apply_patch_path "${_apply_staging_root}/patch.diff")
        file(WRITE "${_apply_patch_path}" "${_apply_patch_content}")

        execute_process(
            COMMAND git apply --3way "${_apply_patch_path}"
            WORKING_DIRECTORY "${_apply_root_b}"
            RESULT_VARIABLE _apply_apply_result
            OUTPUT_VARIABLE _apply_apply_output
            ERROR_VARIABLE _apply_apply_error
        )

        if(NOT _apply_apply_result EQUAL 0)
            message(FATAL_ERROR "echo: apply: git apply --3way failed in ${_apply_root_b}:\n${_apply_apply_error}${_apply_apply_output}")
        endif()

        file(REMOVE_RECURSE "${_apply_staging_root}")

        message(STATUS "✓ applied ${_apply_file_count} file(s): ${_apply_name_a} → ${_apply_name_b}")

        _verify_run_comparison("${_apply_name_a}" "${_apply_name_b}")

        execute_process(
            COMMAND git diff --no-index "${_verify_export_a_dir}" "${_verify_export_b_dir}"
            RESULT_VARIABLE _apply_verify_result
            OUTPUT_VARIABLE _apply_verify_diff
        )

        if(_apply_verify_result EQUAL 0)
            message(STATUS "✓ in sync: ${_apply_name_a} ↔ ${_apply_name_b}")
        else()
            message(WARNING "echo: apply: ${_apply_name_a} and ${_apply_name_b} are out of sync after apply:\n${_apply_verify_diff}")
        endif()
    endif()
endif()
