include("${CMAKE_CURRENT_LIST_DIR}/verify.cmake")

set(_selfapply_identity_file "lexicon/identity.md")

# ============================================================================
# _selfapply_identity_equal — Source Identity scalar fields, namespaceShort
# presence/value, and every Module Pairs / Generated Headers entry, compared
# in declared order between two loaded echo_identity_load registers.
# ============================================================================

function(_selfapply_identity_equal identity_a_prefix identity_b_prefix out_var)
    set(_selfapply_equal 1)

    if(NOT "${${identity_a_prefix}_namespace}" STREQUAL "${${identity_b_prefix}_namespace}")
        set(_selfapply_equal 0)
    endif()
    if(NOT "${${identity_a_prefix}_filePrefix}" STREQUAL "${${identity_b_prefix}_filePrefix}")
        set(_selfapply_equal 0)
    endif()
    if(NOT "${${identity_a_prefix}_macroPrefix}" STREQUAL "${${identity_b_prefix}_macroPrefix}")
        set(_selfapply_equal 0)
    endif()
    if(NOT "${${identity_a_prefix}_moduleVendor}" STREQUAL "${${identity_b_prefix}_moduleVendor}")
        set(_selfapply_equal 0)
    endif()

    if(DEFINED ${identity_a_prefix}_namespaceShort AND DEFINED ${identity_b_prefix}_namespaceShort)
        if(NOT "${${identity_a_prefix}_namespaceShort}" STREQUAL "${${identity_b_prefix}_namespaceShort}")
            set(_selfapply_equal 0)
        endif()
    elseif(DEFINED ${identity_a_prefix}_namespaceShort OR DEFINED ${identity_b_prefix}_namespaceShort)
        set(_selfapply_equal 0)
    endif()

    if(NOT ${identity_a_prefix}_pair_total EQUAL ${identity_b_prefix}_pair_total)
        set(_selfapply_equal 0)
    else()
        set(_selfapply_p 0)
        while(_selfapply_p LESS ${identity_a_prefix}_pair_total)
            if(NOT "${${identity_a_prefix}_pair_${_selfapply_p}_canonical}" STREQUAL "${${identity_b_prefix}_pair_${_selfapply_p}_canonical}")
                set(_selfapply_equal 0)
            endif()
            if(NOT "${${identity_a_prefix}_pair_${_selfapply_p}_local}" STREQUAL "${${identity_b_prefix}_pair_${_selfapply_p}_local}")
                set(_selfapply_equal 0)
            endif()
            math(EXPR _selfapply_p "${_selfapply_p}+1")
        endwhile()
    endif()

    if(NOT ${identity_a_prefix}_header_total EQUAL ${identity_b_prefix}_header_total)
        set(_selfapply_equal 0)
    else()
        set(_selfapply_h 0)
        while(_selfapply_h LESS ${identity_a_prefix}_header_total)
            if(NOT "${${identity_a_prefix}_header_${_selfapply_h}_canonical}" STREQUAL "${${identity_b_prefix}_header_${_selfapply_h}_canonical}")
                set(_selfapply_equal 0)
            endif()
            if(NOT "${${identity_a_prefix}_header_${_selfapply_h}_local}" STREQUAL "${${identity_b_prefix}_header_${_selfapply_h}_local}")
                set(_selfapply_equal 0)
            endif()
            math(EXPR _selfapply_h "${_selfapply_h}+1")
        endwhile()
    endif()

    set(${out_var} "${_selfapply_equal}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _selfapply_all_files — unfiltered `git ls-files` of the whole repository
# (no Sync Ignore, no kernel-class restriction: self-apply re-registers
# every tracked path, provision included).
# ============================================================================

function(_selfapply_all_files root out_prefix)
    execute_process(
        COMMAND git ls-files
        WORKING_DIRECTORY "${root}"
        OUTPUT_VARIABLE _selfapply_ls_output
        RESULT_VARIABLE _selfapply_ls_result
        ERROR_VARIABLE _selfapply_ls_error
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(NOT _selfapply_ls_result EQUAL 0)
        message(FATAL_ERROR "echo: self-apply: git ls-files failed for ${root}: ${_selfapply_ls_error}")
    endif()

    set(_selfapply_count 0)
    if(NOT _selfapply_ls_output STREQUAL "")
        _verify_split_on_delimiter("${_selfapply_ls_output}" "\n" _selfapply_ls_line_total)

        set(_selfapply_i 0)
        while(_selfapply_i LESS _selfapply_ls_line_total)
            set(${out_prefix}_${_selfapply_count} "${_verify_part_${_selfapply_i}}" PARENT_SCOPE)
            math(EXPR _selfapply_count "${_selfapply_count}+1")
            math(EXPR _selfapply_i "${_selfapply_i}+1")
        endwhile()
    endif()

    set(${out_prefix}_total "${_selfapply_count}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _selfapply_roundtrip_probe — echo_roundtrip_check's own derivation
# (inverse(forward(x)) against x, first-divergence offset, centered
# excerpts) without its FATAL_ERROR, so a caller can collect every failing
# file across a whole scope before reporting.
# ============================================================================

function(_selfapply_roundtrip_probe identity_a_prefix identity_b_prefix file_path out_ok_var out_offset_var out_excerpt_a_var out_excerpt_b_var)
    file(READ "${file_path}" _selfapply_roundtrip_original)
    echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_selfapply_roundtrip_original}" _selfapply_roundtrip_forward)
    echo_tokens_inverse("${identity_a_prefix}" "${identity_b_prefix}" "${_selfapply_roundtrip_forward}" _selfapply_roundtrip_back)

    if(_selfapply_roundtrip_back STREQUAL _selfapply_roundtrip_original)
        set(${out_ok_var} 1 PARENT_SCOPE)
        set(${out_offset_var} "" PARENT_SCOPE)
        set(${out_excerpt_a_var} "" PARENT_SCOPE)
        set(${out_excerpt_b_var} "" PARENT_SCOPE)
    else()
        _echo_first_diff_offset("${_selfapply_roundtrip_original}" "${_selfapply_roundtrip_back}" _selfapply_roundtrip_offset)
        _echo_centered_excerpt("${_selfapply_roundtrip_original}" "${_selfapply_roundtrip_offset}" _selfapply_roundtrip_excerpt_a)
        _echo_centered_excerpt("${_selfapply_roundtrip_back}" "${_selfapply_roundtrip_offset}" _selfapply_roundtrip_excerpt_b)
        set(${out_ok_var} 0 PARENT_SCOPE)
        set(${out_offset_var} "${_selfapply_roundtrip_offset}" PARENT_SCOPE)
        set(${out_excerpt_a_var} "${_selfapply_roundtrip_excerpt_a}" PARENT_SCOPE)
        set(${out_excerpt_b_var} "${_selfapply_roundtrip_excerpt_b}" PARENT_SCOPE)
    endif()
endfunction()

# ============================================================================
# _selfapply_refusal_gate — every scoped text file must round-trip clean
# under OLD->NEW; every failure is collected before one FATAL_ERROR, zero
# writes attempted. lexicon/identity.md is excluded: its worktree content is
# the declared post-state, not a file still carrying the OLD register.
# ============================================================================

function(_selfapply_refusal_gate root scoped_prefix identity_a_prefix identity_b_prefix)
    set(_selfapply_findings "")

    set(_selfapply_r 0)
    while(_selfapply_r LESS ${scoped_prefix}_total)
        set(_selfapply_relative_path "${${scoped_prefix}_${_selfapply_r}}")

        if(NOT _selfapply_relative_path STREQUAL _selfapply_identity_file)
            set(_selfapply_absolute_path "${root}/${_selfapply_relative_path}")
            _verify_detect_binary("${_selfapply_absolute_path}" _selfapply_is_binary _selfapply_probe_content)

            if(NOT _selfapply_is_binary)
                _selfapply_roundtrip_probe("${identity_a_prefix}" "${identity_b_prefix}" "${_selfapply_absolute_path}" _selfapply_ok _selfapply_offset _selfapply_excerpt_a _selfapply_excerpt_b)
                if(NOT _selfapply_ok)
                    list(APPEND _selfapply_findings "${_selfapply_relative_path} (first divergence at offset ${_selfapply_offset})\n    old: ...${_selfapply_excerpt_a}...\n    new: ...${_selfapply_excerpt_b}...")
                endif()
            endif()
        endif()

        math(EXPR _selfapply_r "${_selfapply_r}+1")
    endwhile()

    if(_selfapply_findings)
        string(JOIN "\n" _selfapply_message ${_selfapply_findings})
        message(FATAL_ERROR "echo: self-apply: refusal gate failed, zero writes:\n${_selfapply_message}")
    endif()
endfunction()

# ============================================================================
# _selfapply_stage — every scoped file transformed OLD->NEW into a staging
# tree: paths always through echo_tokens_forward, binary content copied
# byte-for-byte, text content copied then rewritten via the COPY_FILE-then-
# WRITE technique (permission bits from COPY_FILE, WRITE leaves them
# untouched). lexicon/identity.md's worktree content is the post-state
# already — carried through byte-verbatim, never token-transformed.
# ============================================================================

function(_selfapply_stage root scoped_prefix identity_a_prefix identity_b_prefix staging_dir out_plan_prefix)
    set(_selfapply_rename_count 0)

    set(_selfapply_e 0)
    while(_selfapply_e LESS ${scoped_prefix}_total)
        set(_selfapply_relative_path "${${scoped_prefix}_${_selfapply_e}}")
        set(_selfapply_absolute_path "${root}/${_selfapply_relative_path}")
        set(_selfapply_is_identity 0)
        if(_selfapply_relative_path STREQUAL _selfapply_identity_file)
            set(_selfapply_is_identity 1)
        endif()

        if(_selfapply_is_identity)
            set(_selfapply_transformed_path "${_selfapply_relative_path}")
        else()
            echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_selfapply_relative_path}" _selfapply_transformed_path)
        endif()

        set(${out_plan_prefix}_${_selfapply_e}_original "${_selfapply_relative_path}" PARENT_SCOPE)
        set(${out_plan_prefix}_${_selfapply_e}_staged "${_selfapply_transformed_path}" PARENT_SCOPE)

        if(NOT _selfapply_transformed_path STREQUAL _selfapply_relative_path)
            math(EXPR _selfapply_rename_count "${_selfapply_rename_count}+1")
        endif()

        set(_selfapply_destination "${staging_dir}/${_selfapply_transformed_path}")
        get_filename_component(_selfapply_destination_dir "${_selfapply_destination}" DIRECTORY)
        file(MAKE_DIRECTORY "${_selfapply_destination_dir}")

        _verify_detect_binary("${_selfapply_absolute_path}" _selfapply_is_binary _selfapply_original_content)

        if(_selfapply_is_binary OR _selfapply_is_identity)
            file(COPY_FILE "${_selfapply_absolute_path}" "${_selfapply_destination}")
        else()
            echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_selfapply_original_content}" _selfapply_transformed_content)
            file(COPY_FILE "${_selfapply_absolute_path}" "${_selfapply_destination}")
            file(WRITE "${_selfapply_destination}" "${_selfapply_transformed_content}")
        endif()

        math(EXPR _selfapply_e "${_selfapply_e}+1")
    endwhile()

    set(${out_plan_prefix}_total "${${scoped_prefix}_total}" PARENT_SCOPE)
    set(${out_plan_prefix}_rename_total "${_selfapply_rename_count}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _selfapply_commit — runs only after _selfapply_stage has fully populated
# staging_dir with zero errors. Originals whose staged path differs are
# removed first, then every staged file is copied over the repo working
# tree at its staged path (COPY_FILE carries the permission bits staging
# already inherited from the original).
# ============================================================================

function(_selfapply_commit root staging_dir plan_prefix)
    set(_selfapply_c 0)
    while(_selfapply_c LESS ${plan_prefix}_total)
        set(_selfapply_original "${${plan_prefix}_${_selfapply_c}_original}")
        set(_selfapply_staged "${${plan_prefix}_${_selfapply_c}_staged}")
        if(NOT _selfapply_staged STREQUAL _selfapply_original)
            file(REMOVE "${root}/${_selfapply_original}")
        endif()
        math(EXPR _selfapply_c "${_selfapply_c}+1")
    endwhile()

    set(_selfapply_c 0)
    while(_selfapply_c LESS ${plan_prefix}_total)
        set(_selfapply_staged "${${plan_prefix}_${_selfapply_c}_staged}")
        set(_selfapply_destination "${root}/${_selfapply_staged}")
        get_filename_component(_selfapply_destination_dir "${_selfapply_destination}" DIRECTORY)
        file(MAKE_DIRECTORY "${_selfapply_destination_dir}")
        file(COPY_FILE "${staging_dir}/${_selfapply_staged}" "${_selfapply_destination}")
        math(EXPR _selfapply_c "${_selfapply_c}+1")
    endwhile()
endfunction()

# ============================================================================
# Direct-invocation gate — same technique as verify.cmake's own gate, keyed
# to this file's name so the include() above never runs verify.cmake's
# comparison-verb block here.
# ============================================================================

get_filename_component(_selfapply_self_name "${CMAKE_CURRENT_LIST_FILE}" NAME)
set(_selfapply_self_index -1)
set(_selfapply_i 0)
while(_selfapply_i LESS CMAKE_ARGC)
    get_filename_component(_selfapply_argv_name "${CMAKE_ARGV${_selfapply_i}}" NAME)
    if(_selfapply_argv_name STREQUAL _selfapply_self_name)
        set(_selfapply_self_index ${_selfapply_i})
    endif()
    math(EXPR _selfapply_i "${_selfapply_i}+1")
endwhile()

if(_selfapply_self_index GREATER -1)
    include("${CMAKE_CURRENT_LIST_DIR}/echo.cmake")

    set(_selfapply_user_arg_count 0)
    math(EXPR _selfapply_user_arg_start "${_selfapply_self_index}+1")
    set(_selfapply_i ${_selfapply_user_arg_start})
    while(_selfapply_i LESS CMAKE_ARGC)
        if(_selfapply_user_arg_count EQUAL 0)
            set(_selfapply_name_arg "${CMAKE_ARGV${_selfapply_i}}")
        endif()
        math(EXPR _selfapply_user_arg_count "${_selfapply_user_arg_count}+1")
        math(EXPR _selfapply_i "${_selfapply_i}+1")
    endwhile()

    if(NOT _selfapply_user_arg_count EQUAL 1)
        message(FATAL_ERROR "usage: cmake -P self-apply.cmake <frameworkNameOrPath>\nA name containing '/' is treated as a literal root path instead of a frameworks.md registry lookup.")
    endif()

    _verify_resolve_root("${_selfapply_name_arg}" _selfapply_root)

    set(_selfapply_staging_root "${_verify_temp_dir}/echo/self-apply")
    file(REMOVE_RECURSE "${_selfapply_staging_root}")
    file(MAKE_DIRECTORY "${_selfapply_staging_root}")

    execute_process(
        COMMAND git show HEAD:${_selfapply_identity_file}
        WORKING_DIRECTORY "${_selfapply_root}"
        OUTPUT_VARIABLE _selfapply_old_identity_content
        RESULT_VARIABLE _selfapply_show_result
        ERROR_VARIABLE _selfapply_show_error
    )

    if(NOT _selfapply_show_result EQUAL 0)
        message(FATAL_ERROR "echo: self-apply: no committed ${_selfapply_identity_file} at HEAD in ${_selfapply_root}: ${_selfapply_show_error}")
    endif()

    set(_selfapply_old_identity_path "${_selfapply_staging_root}/old-identity.md")
    file(WRITE "${_selfapply_old_identity_path}" "${_selfapply_old_identity_content}")

    echo_identity_load("${_selfapply_old_identity_path}" _selfapply_identity_old)
    echo_identity_load("${_selfapply_root}/${_selfapply_identity_file}" _selfapply_identity_new)

    _selfapply_identity_equal(_selfapply_identity_old _selfapply_identity_new _selfapply_unchanged)

    if(_selfapply_unchanged)
        message(STATUS "✓ nothing to apply")
    else()
        _selfapply_all_files("${_selfapply_root}" _selfapply_scoped)

        _selfapply_refusal_gate("${_selfapply_root}" _selfapply_scoped _selfapply_identity_old _selfapply_identity_new)

        set(_selfapply_tree_staging "${_selfapply_staging_root}/tree")
        file(MAKE_DIRECTORY "${_selfapply_tree_staging}")

        _selfapply_stage("${_selfapply_root}" _selfapply_scoped _selfapply_identity_old _selfapply_identity_new "${_selfapply_tree_staging}" _selfapply_plan)

        _selfapply_commit("${_selfapply_root}" "${_selfapply_tree_staging}" _selfapply_plan)

        message(STATUS "✓ self-applied ${_selfapply_scoped_total} file(s), ${_selfapply_plan_rename_total} renamed: ${_selfapply_root}")
    endif()

    file(REMOVE_RECURSE "${_selfapply_staging_root}")
endif()
