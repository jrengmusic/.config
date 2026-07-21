if(WIN32)
    set(_verify_temp_dir "$ENV{TEMP}")
elseif(DEFINED ENV{TMPDIR})
    set(_verify_temp_dir "$ENV{TMPDIR}")
else()
    set(_verify_temp_dir "/tmp")
endif()

set(_verify_export_root "${_verify_temp_dir}/echo/verify")
set(_verify_export_a_dir "${_verify_export_root}/a")
set(_verify_export_b_dir "${_verify_export_root}/b")

# ============================================================================
# _verify_split_on_delimiter — manual FIND-based scan splitting on any
# literal delimiter string, so a delimiter inside a captured part is never
# misread as further separators.
# ============================================================================

function(_verify_split_on_delimiter content delimiter out_count_var)
    set(_verify_remaining "${content}")
    set(_verify_count 0)
    set(_verify_done 0)
    string(LENGTH "${delimiter}" _verify_delimiter_len)
    while(NOT _verify_done)
        string(FIND "${_verify_remaining}" "${delimiter}" _verify_pos)
        if(_verify_pos EQUAL -1)
            set(_verify_part_${_verify_count} "${_verify_remaining}" PARENT_SCOPE)
            math(EXPR _verify_count "${_verify_count}+1")
            set(_verify_done 1)
        else()
            string(SUBSTRING "${_verify_remaining}" 0 ${_verify_pos} _verify_part)
            set(_verify_part_${_verify_count} "${_verify_part}" PARENT_SCOPE)
            math(EXPR _verify_count "${_verify_count}+1")
            math(EXPR _verify_next_start "${_verify_pos}+${_verify_delimiter_len}")
            string(SUBSTRING "${_verify_remaining}" ${_verify_next_start} -1 _verify_remaining)
        endif()
    endwhile()
    set(${out_count_var} "${_verify_count}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _verify_split_path — path segments (split on "/") copied into a
# caller-chosen variable prefix, so two splits can coexist in one scope.
# ============================================================================

function(_verify_split_path path out_prefix out_count_var)
    _verify_split_on_delimiter("${path}" "/" _verify_split_path_count)
    set(_verify_p 0)
    while(_verify_p LESS _verify_split_path_count)
        set(${out_prefix}_${_verify_p} "${_verify_part_${_verify_p}}" PARENT_SCOPE)
        math(EXPR _verify_p "${_verify_p}+1")
    endwhile()
    set(${out_count_var} "${_verify_split_path_count}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _verify_segment_glob_match — one path segment against one pattern segment,
# "*" matching any run of characters within that segment.
# ============================================================================

function(_verify_segment_glob_match pattern_segment candidate_segment out_match_var)
    string(FIND "${pattern_segment}" "*" _verify_star_pos)

    if(_verify_star_pos EQUAL -1)
        if(candidate_segment STREQUAL pattern_segment)
            set(_verify_match 1)
        else()
            set(_verify_match 0)
        endif()
    else()
        _verify_split_on_delimiter("${pattern_segment}" "*" _verify_chunk_total)
        set(_verify_match 1)
        set(_verify_cursor 0)
        string(LENGTH "${candidate_segment}" _verify_candidate_len)

        set(_verify_first_chunk "${_verify_part_0}")
        string(LENGTH "${_verify_first_chunk}" _verify_first_len)
        if(_verify_first_len GREATER 0)
            string(SUBSTRING "${candidate_segment}" 0 ${_verify_first_len} _verify_candidate_prefix)
            if(NOT _verify_candidate_prefix STREQUAL _verify_first_chunk)
                set(_verify_match 0)
            endif()
            set(_verify_cursor ${_verify_first_len})
        endif()

        math(EXPR _verify_last_index "${_verify_chunk_total}-1")
        set(_verify_last_chunk "${_verify_part_${_verify_last_index}}")
        string(LENGTH "${_verify_last_chunk}" _verify_last_len)
        if(_verify_match AND _verify_last_len GREATER 0)
            math(EXPR _verify_suffix_start "${_verify_candidate_len}-${_verify_last_len}")
            if(_verify_suffix_start LESS _verify_cursor)
                set(_verify_match 0)
            else()
                string(SUBSTRING "${candidate_segment}" ${_verify_suffix_start} -1 _verify_candidate_suffix)
                if(NOT _verify_candidate_suffix STREQUAL _verify_last_chunk)
                    set(_verify_match 0)
                endif()
            endif()
        endif()

        if(_verify_match AND _verify_chunk_total GREATER 2)
            set(_verify_mid_index 1)
            math(EXPR _verify_mid_last "${_verify_chunk_total}-2")
            while(_verify_mid_index LESS_EQUAL _verify_mid_last AND _verify_match)
                set(_verify_mid_chunk "${_verify_part_${_verify_mid_index}}")
                string(LENGTH "${_verify_mid_chunk}" _verify_mid_len)
                if(_verify_mid_len GREATER 0)
                    string(SUBSTRING "${candidate_segment}" ${_verify_cursor} -1 _verify_search_space)
                    string(FIND "${_verify_search_space}" "${_verify_mid_chunk}" _verify_found_pos)
                    if(_verify_found_pos EQUAL -1)
                        set(_verify_match 0)
                    else()
                        math(EXPR _verify_cursor "${_verify_cursor}+${_verify_found_pos}+${_verify_mid_len}")
                    endif()
                endif()
                math(EXPR _verify_mid_index "${_verify_mid_index}+1")
            endwhile()
        endif()
    endif()

    set(${out_match_var} "${_verify_match}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _verify_pattern_matches_path — one Sync Ignore pattern (already stripped
# of leading "!") against one repo-relative path. A pattern without "/"
# matches the path's basename at any depth; a pattern with "/" is anchored
# at the repo root and "**" crosses any number of segments.
# ============================================================================

function(_verify_pattern_matches_path pattern relative_path out_match_var)
    string(FIND "${pattern}" "/" _verify_slash_pos)

    if(_verify_slash_pos EQUAL -1)
        _verify_split_path("${relative_path}" _verify_pmp_candidate _verify_pmp_candidate_total)
        math(EXPR _verify_pmp_last_index "${_verify_pmp_candidate_total}-1")
        _verify_segment_glob_match("${pattern}" "${_verify_pmp_candidate_${_verify_pmp_last_index}}" _verify_pmp_match)
    else()
        _verify_split_path("${pattern}" _verify_pmp_pattern _verify_pmp_pattern_total)
        _verify_split_path("${relative_path}" _verify_pmp_candidate _verify_pmp_candidate_total)

        set(_verify_pmp_i 0)
        set(_verify_pmp_j 0)
        set(_verify_pmp_star_j -1)
        set(_verify_pmp_star_i -1)
        set(_verify_pmp_ok 1)
        set(_verify_pmp_running 1)

        while(_verify_pmp_running)
            if(_verify_pmp_i LESS _verify_pmp_candidate_total)
                if(_verify_pmp_j LESS _verify_pmp_pattern_total AND _verify_pmp_pattern_${_verify_pmp_j} STREQUAL "**")
                    set(_verify_pmp_star_j ${_verify_pmp_j})
                    set(_verify_pmp_star_i ${_verify_pmp_i})
                    math(EXPR _verify_pmp_j "${_verify_pmp_j}+1")
                else()
                    set(_verify_pmp_segment_ok 0)
                    if(_verify_pmp_j LESS _verify_pmp_pattern_total)
                        _verify_segment_glob_match("${_verify_pmp_pattern_${_verify_pmp_j}}" "${_verify_pmp_candidate_${_verify_pmp_i}}" _verify_pmp_segment_ok)
                    endif()

                    if(_verify_pmp_segment_ok)
                        math(EXPR _verify_pmp_i "${_verify_pmp_i}+1")
                        math(EXPR _verify_pmp_j "${_verify_pmp_j}+1")
                    elseif(_verify_pmp_star_j GREATER -1)
                        math(EXPR _verify_pmp_star_i "${_verify_pmp_star_i}+1")
                        set(_verify_pmp_i ${_verify_pmp_star_i})
                        math(EXPR _verify_pmp_j "${_verify_pmp_star_j}+1")
                    else()
                        set(_verify_pmp_ok 0)
                        set(_verify_pmp_running 0)
                    endif()
                endif()
            else()
                set(_verify_pmp_running 0)
            endif()
        endwhile()

        if(_verify_pmp_ok)
            while(_verify_pmp_j LESS _verify_pmp_pattern_total AND _verify_pmp_pattern_${_verify_pmp_j} STREQUAL "**")
                math(EXPR _verify_pmp_j "${_verify_pmp_j}+1")
            endwhile()
            if(NOT _verify_pmp_j EQUAL _verify_pmp_pattern_total)
                set(_verify_pmp_ok 0)
            endif()
        endif()

        set(_verify_pmp_match "${_verify_pmp_ok}")
    endif()

    set(${out_match_var} "${_verify_pmp_match}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _verify_parse_ignore_patterns — Sync Ignore section text lines (fence
# lines excluded) into indexed pattern/negate pairs, negation stripped once.
# ============================================================================

function(_verify_parse_ignore_patterns ignore_section_prefix out_prefix)
    set(_verify_count 0)
    set(_verify_k 0)
    while(_verify_k LESS ${ignore_section_prefix}_text_total)
        set(_verify_line "${${ignore_section_prefix}_text_${_verify_k}}")
        if(NOT _verify_line STREQUAL "```")
            string(LENGTH "${_verify_line}" _verify_line_len)
            if(_verify_line_len GREATER 0)
                string(SUBSTRING "${_verify_line}" 0 1 _verify_first_char)
                if(_verify_first_char STREQUAL "!")
                    math(EXPR _verify_rest_len "${_verify_line_len}-1")
                    string(SUBSTRING "${_verify_line}" 1 ${_verify_rest_len} _verify_pattern_text)
                    set(_verify_negate 1)
                else()
                    set(_verify_pattern_text "${_verify_line}")
                    set(_verify_negate 0)
                endif()
                set(${out_prefix}_pattern_${_verify_count} "${_verify_pattern_text}" PARENT_SCOPE)
                set(${out_prefix}_negate_${_verify_count} "${_verify_negate}" PARENT_SCOPE)
                math(EXPR _verify_count "${_verify_count}+1")
            endif()
        endif()
        math(EXPR _verify_k "${_verify_k}+1")
    endwhile()
    set(${out_prefix}_total "${_verify_count}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _verify_path_excluded — applies every Sync Ignore pattern in declared
# order, last match wins (negation re-includes).
# ============================================================================

function(_verify_path_excluded pattern_prefix pattern_total relative_path out_excluded_var)
    set(_verify_excluded 0)
    set(_verify_p 0)
    while(_verify_p LESS pattern_total)
        set(_verify_pattern_text "${${pattern_prefix}_pattern_${_verify_p}}")
        set(_verify_pattern_negate "${${pattern_prefix}_negate_${_verify_p}}")
        _verify_pattern_matches_path("${_verify_pattern_text}" "${relative_path}" _verify_matched)
        if(_verify_matched)
            if(_verify_pattern_negate)
                set(_verify_excluded 0)
            else()
                set(_verify_excluded 1)
            endif()
        endif()
        math(EXPR _verify_p "${_verify_p}+1")
    endwhile()
    set(${out_excluded_var} "${_verify_excluded}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _verify_resolve_root — a name argument containing "/" is a literal root
# path (tilde-expanded here); otherwise it is resolved via get_framework_root.
# ============================================================================

function(_verify_resolve_root name_arg out_root_var)
    string(FIND "${name_arg}" "/" _verify_slash_pos)

    if(NOT _verify_slash_pos EQUAL -1)
        set(_verify_root "${name_arg}")
        string(FIND "${_verify_root}" "~/" _verify_tilde_pos)
        if(_verify_tilde_pos EQUAL 0)
            string(SUBSTRING "${_verify_root}" 2 -1 _verify_root_remainder)
            set(_verify_root "$ENV{HOME}/${_verify_root_remainder}")
        endif()
    else()
        get_framework_root("${name_arg}" _verify_root)
    endif()

    if(NOT IS_DIRECTORY "${_verify_root}")
        message(FATAL_ERROR "echo: resolved root does not exist: ${_verify_root}")
    endif()

    set(${out_root_var} "${_verify_root}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _verify_kernel_modules — Modules-table data rows whose class is "kernel".
# ============================================================================

function(_verify_kernel_modules modules_section_prefix out_prefix)
    set(_verify_count 0)
    set(_verify_k 0)
    while(_verify_k LESS ${modules_section_prefix}_row_total)
        if(${modules_section_prefix}_row_${_verify_k}_role STREQUAL "data")
            echo_table_require(${modules_section_prefix}_row_${_verify_k} "module" _verify_module_name)
            echo_table_require(${modules_section_prefix}_row_${_verify_k} "class" _verify_module_class)
            if(_verify_module_class STREQUAL "kernel")
                set(${out_prefix}_${_verify_count} "${_verify_module_name}" PARENT_SCOPE)
                math(EXPR _verify_count "${_verify_count}+1")
            endif()
        endif()
        math(EXPR _verify_k "${_verify_k}+1")
    endwhile()
    set(${out_prefix}_total "${_verify_count}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _verify_cross_consistency — A's kernel module names transformed into B's
# register must equal B's declared kernel set.
# ============================================================================

function(_verify_cross_consistency identity_a_prefix identity_b_prefix kernel_a_prefix kernel_b_prefix name_a name_b)
    set(_verify_findings "")

    set(_verify_i 0)
    while(_verify_i LESS ${kernel_a_prefix}_total)
        set(_verify_module_name "${${kernel_a_prefix}_${_verify_i}}")
        echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_verify_module_name}" _verify_transformed)

        set(_verify_found 0)
        set(_verify_j 0)
        while(_verify_j LESS ${kernel_b_prefix}_total)
            if("${${kernel_b_prefix}_${_verify_j}}" STREQUAL "${_verify_transformed}")
                set(_verify_found 1)
            endif()
            math(EXPR _verify_j "${_verify_j}+1")
        endwhile()

        if(NOT _verify_found)
            list(APPEND _verify_findings "${name_a}: kernel module '${_verify_module_name}' transforms to '${_verify_transformed}', not present in ${name_b} kernel set")
        endif()

        math(EXPR _verify_i "${_verify_i}+1")
    endwhile()

    if(NOT ${kernel_a_prefix}_total EQUAL ${kernel_b_prefix}_total)
        list(APPEND _verify_findings "kernel module count mismatch: ${name_a} has ${${kernel_a_prefix}_total}, ${name_b} has ${${kernel_b_prefix}_total}")
    endif()

    if(_verify_findings)
        string(JOIN "\n" _verify_message ${_verify_findings})
        message(FATAL_ERROR "echo: kernel module sets diverge between ${name_a} and ${name_b}:\n${_verify_message}")
    endif()
endfunction()

# ============================================================================
# _verify_scoped_files — git ls-files (tracked ∪ untracked-not-ignored) under
# every kernel module directory, deduplicated (a path can surface from both
# --cached and --others in edge states), then filtered through Sync Ignore
# and through on-disk existence: a tracked path absent from the working tree
# is a pending deletion, not compared content.
# ============================================================================

function(_verify_scoped_files root kernel_prefix pattern_prefix out_prefix)
    set(_verify_file_count 0)
    set(_verify_seen_paths "")

    set(_verify_m 0)
    while(_verify_m LESS ${kernel_prefix}_total)
        set(_verify_module_name "${${kernel_prefix}_${_verify_m}}")

        execute_process(
            COMMAND git ls-files --cached --others --exclude-standard -- "${_verify_module_name}/"
            WORKING_DIRECTORY "${root}"
            OUTPUT_VARIABLE _verify_ls_output
            RESULT_VARIABLE _verify_ls_result
            ERROR_VARIABLE _verify_ls_error
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )

        if(NOT _verify_ls_result EQUAL 0)
            message(FATAL_ERROR "echo: git ls-files failed for ${root}/${_verify_module_name}: ${_verify_ls_error}")
        endif()

        if(NOT _verify_ls_output STREQUAL "")
            _verify_split_on_delimiter("${_verify_ls_output}" "\n" _verify_ls_line_total)

            set(_verify_ls_i 0)
            while(_verify_ls_i LESS _verify_ls_line_total)
                set(_verify_relative_path "${_verify_part_${_verify_ls_i}}")
                set(_verify_absolute_path "${root}/${_verify_relative_path}")

                list(FIND _verify_seen_paths "${_verify_relative_path}" _verify_seen_index)

                if(_verify_seen_index EQUAL -1)
                    list(APPEND _verify_seen_paths "${_verify_relative_path}")

                    if(EXISTS "${_verify_absolute_path}")
                        _verify_path_excluded("${pattern_prefix}" "${${pattern_prefix}_total}" "${_verify_relative_path}" _verify_is_excluded)

                        if(NOT _verify_is_excluded)
                            set(${out_prefix}_${_verify_file_count} "${_verify_relative_path}" PARENT_SCOPE)
                            math(EXPR _verify_file_count "${_verify_file_count}+1")
                        endif()
                    endif()
                endif()

                math(EXPR _verify_ls_i "${_verify_ls_i}+1")
            endwhile()
        endif()

        math(EXPR _verify_m "${_verify_m}+1")
    endwhile()

    set(${out_prefix}_total "${_verify_file_count}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _verify_scope_relay — hands content back through exactly one function
# return, so a caller reading it afterward observes whatever a PARENT_SCOPE
# hop does to the value (backing _verify_detect_binary's probe: a value
# crossing a PARENT_SCOPE set() truncates at its first embedded NUL byte,
# while a same-scope set() does not).
# ============================================================================

function(_verify_scope_relay content out_var)
    set(${out_var} "${content}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _verify_hex_find_aligned_nul — a HEX-encoded byte string (2 hex digits per
# source byte) searched for a "00" pair landing on a byte boundary. A "00"
# occurrence spanning two adjacent bytes' hex digits (e.g. byte 0x10 next to
# byte 0x0A encodes as "100a", which contains "00" one digit off-boundary)
# is not a NUL byte and is skipped; the cursor resumes one digit past it.
# ============================================================================

function(_verify_hex_find_aligned_nul hex_content out_found_var)
    set(_verify_cursor 0)
    set(_verify_found 0)
    set(_verify_done 0)
    while(NOT _verify_done)
        string(SUBSTRING "${hex_content}" ${_verify_cursor} -1 _verify_search_space)
        string(FIND "${_verify_search_space}" "00" _verify_hit_pos)
        if(_verify_hit_pos EQUAL -1)
            set(_verify_done 1)
        else()
            math(EXPR _verify_absolute_pos "${_verify_cursor}+${_verify_hit_pos}")
            math(EXPR _verify_parity "${_verify_absolute_pos}%2")
            if(_verify_parity EQUAL 0)
                set(_verify_found 1)
                set(_verify_done 1)
            else()
                math(EXPR _verify_cursor "${_verify_absolute_pos}+1")
            endif()
        endif()
    endwhile()
    set(${out_found_var} "${_verify_found}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _verify_hex_decode — a HEX-encoded byte string turned back into the exact
# source bytes, one byte at a time (no built-in HEX-to-content primitive).
# Reserved for content already established NUL-free by
# _verify_hex_find_aligned_nul; every decoded byte is representable via
# string(ASCII).
# ============================================================================

function(_verify_hex_decode hex_content out_content_var)
    string(LENGTH "${hex_content}" _verify_hex_len)
    math(EXPR _verify_byte_total "${_verify_hex_len}/2")

    set(_verify_decoded "")
    set(_verify_byte_i 0)
    while(_verify_byte_i LESS _verify_byte_total)
        math(EXPR _verify_hex_pos "${_verify_byte_i}*2")
        string(SUBSTRING "${hex_content}" ${_verify_hex_pos} 2 _verify_byte_hex)
        math(EXPR _verify_byte_dec "0x${_verify_byte_hex}")
        string(ASCII ${_verify_byte_dec} _verify_byte_char)
        string(APPEND _verify_decoded "${_verify_byte_char}")
        math(EXPR _verify_byte_i "${_verify_byte_i}+1")
    endwhile()

    set(${out_content_var} "${_verify_decoded}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _verify_detect_binary — plain file(READ) opens in text mode and collapses
# every CRLF pair to LF, so its content can read shorter than the file's
# on-disk size for reasons having nothing to do with binary content. That
# collapse is applied uniformly, so comparing the read content's length
# against its own length after one more PARENT_SCOPE hop (rather than
# against file(SIZE)) still isolates the hop's actual signal: a value
# crossing PARENT_SCOPE truncates at its first embedded NUL byte, so a
# mismatch there means the file is binary regardless of what the initial
# read did to its line endings.
#
# When the file's on-disk size already equals the plain read's length, no
# CRLF collapse occurred and that content is used as-is (byte-exact, cheap:
# the common case for this tree). When it differs, the CRLF collapse means
# plain-read content cannot be trusted for output; the file is re-read as
# HEX (immune to text-mode translation) and scanned byte-aligned for an
# embedded NUL. A NUL found there is real binary content; none found means
# text carrying CR bytes (CRLF and/or BOM), decoded back to its exact
# original bytes for the caller. No extension list, no byte sniffing. Text
# content (out_is_binary 0) is exact source bytes; binary content is left
# empty (unusable, never read by the caller) since the caller copies binary
# files by path instead.
# ============================================================================

function(_verify_detect_binary file_path out_is_binary_var out_content_var)
    file(READ "${file_path}" _verify_raw_content)
    string(LENGTH "${_verify_raw_content}" _verify_len_raw)
    file(SIZE "${file_path}" _verify_len_disk)

    if(_verify_len_raw EQUAL _verify_len_disk)
        _verify_scope_relay("${_verify_raw_content}" _verify_relayed_content)
        string(LENGTH "${_verify_relayed_content}" _verify_len_relayed)

        if(_verify_len_relayed EQUAL _verify_len_raw)
            set(${out_is_binary_var} 0 PARENT_SCOPE)
            set(${out_content_var} "${_verify_raw_content}" PARENT_SCOPE)
        else()
            set(${out_is_binary_var} 1 PARENT_SCOPE)
            set(${out_content_var} "" PARENT_SCOPE)
        endif()
    else()
        file(READ "${file_path}" _verify_hex_content HEX)
        _verify_hex_find_aligned_nul("${_verify_hex_content}" _verify_has_nul)

        if(_verify_has_nul)
            set(${out_is_binary_var} 1 PARENT_SCOPE)
            set(${out_content_var} "" PARENT_SCOPE)
        else()
            _verify_hex_decode("${_verify_hex_content}" _verify_exact_content)
            set(${out_is_binary_var} 0 PARENT_SCOPE)
            set(${out_content_var} "${_verify_exact_content}" PARENT_SCOPE)
        endif()
    endif()
endfunction()

# ============================================================================
# _verify_export_forward — scoped A files transformed A->B; the relative
# path always goes through echo_tokens_forward. Text content is transformed
# A->B with round-trip enforced per file; binary content is copied
# byte-for-byte (no token register, no round-trip to enforce).
# ============================================================================

function(_verify_export_forward root_a scoped_prefix identity_a_prefix identity_b_prefix export_dir)
    set(_verify_e 0)
    while(_verify_e LESS ${scoped_prefix}_total)
        set(_verify_relative_path "${${scoped_prefix}_${_verify_e}}")
        set(_verify_absolute_path "${root_a}/${_verify_relative_path}")

        echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_verify_relative_path}" _verify_transformed_path)
        set(_verify_destination "${export_dir}/${_verify_transformed_path}")
        get_filename_component(_verify_destination_dir "${_verify_destination}" DIRECTORY)
        file(MAKE_DIRECTORY "${_verify_destination_dir}")

        _verify_detect_binary("${_verify_absolute_path}" _verify_is_binary _verify_original_content)

        if(_verify_is_binary)
            file(COPY_FILE "${_verify_absolute_path}" "${_verify_destination}")
        else()
            echo_roundtrip_check("${identity_a_prefix}" "${identity_b_prefix}" "${_verify_absolute_path}")
            echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_verify_original_content}" _verify_transformed_content)
            # COPY_FILE first establishes the source's permission bits on the
            # destination; WRITE then overwrites content in place without
            # resetting them (WRITE on a new path defaults to umask instead).
            file(COPY_FILE "${_verify_absolute_path}" "${_verify_destination}")
            file(WRITE "${_verify_destination}" "${_verify_transformed_content}")
        endif()

        math(EXPR _verify_e "${_verify_e}+1")
    endwhile()
endfunction()

# ============================================================================
# _verify_export_raw — scoped B files copied byte-for-byte into export_dir.
# ============================================================================

function(_verify_export_raw root_b scoped_prefix export_dir)
    set(_verify_e 0)
    while(_verify_e LESS ${scoped_prefix}_total)
        set(_verify_relative_path "${${scoped_prefix}_${_verify_e}}")
        set(_verify_source "${root_b}/${_verify_relative_path}")
        set(_verify_destination "${export_dir}/${_verify_relative_path}")
        get_filename_component(_verify_destination_dir "${_verify_destination}" DIRECTORY)
        file(MAKE_DIRECTORY "${_verify_destination_dir}")
        file(COPY_FILE "${_verify_source}" "${_verify_destination}")
        math(EXPR _verify_e "${_verify_e}+1")
    endwhile()
endfunction()

# ============================================================================
# _verify_run_comparison — resolves both roots, checks kernel-module cross
# consistency, then populates _verify_export_a_dir / _verify_export_b_dir
# with the scoped, ignore-filtered, A->B-transformed export.
# ============================================================================

function(_verify_run_comparison name_a name_b)
    _verify_resolve_root("${name_a}" _verify_root_a)
    _verify_resolve_root("${name_b}" _verify_root_b)

    echo_identity_load("${_verify_root_a}/lexicon/identity.md" _verify_identity_a)
    echo_identity_load("${_verify_root_b}/lexicon/identity.md" _verify_identity_b)

    echo_table_parse("${_verify_root_a}/lexicon/identity.md" _verify_doc_a)
    echo_table_section(_verify_doc_a "Modules" _verify_modules_a)
    echo_table_parse("${_verify_root_b}/lexicon/identity.md" _verify_doc_b)
    echo_table_section(_verify_doc_b "Modules" _verify_modules_b)

    _verify_kernel_modules(_verify_modules_a _verify_kernel_a)
    _verify_kernel_modules(_verify_modules_b _verify_kernel_b)

    _verify_cross_consistency(_verify_identity_a _verify_identity_b _verify_kernel_a _verify_kernel_b "${name_a}" "${name_b}")

    echo_table_section(_verify_doc_a "Sync Ignore" _verify_ignore_a)
    echo_table_section(_verify_doc_b "Sync Ignore" _verify_ignore_b)
    _verify_parse_ignore_patterns(_verify_ignore_a _verify_pattern_a)
    _verify_parse_ignore_patterns(_verify_ignore_b _verify_pattern_b)

    file(REMOVE_RECURSE "${_verify_export_a_dir}")
    file(REMOVE_RECURSE "${_verify_export_b_dir}")
    file(MAKE_DIRECTORY "${_verify_export_a_dir}")
    file(MAKE_DIRECTORY "${_verify_export_b_dir}")

    _verify_scoped_files("${_verify_root_a}" _verify_kernel_a _verify_pattern_a _verify_scoped_a)
    _verify_scoped_files("${_verify_root_b}" _verify_kernel_b _verify_pattern_b _verify_scoped_b)

    _verify_export_forward("${_verify_root_a}" _verify_scoped_a _verify_identity_a _verify_identity_b "${_verify_export_a_dir}")
    _verify_export_raw("${_verify_root_b}" _verify_scoped_b "${_verify_export_b_dir}")
endfunction()

# ============================================================================
# Direct-invocation gate — the block below runs only when this file is the
# script named on the command line, never when included as a library
# (compare CMAKE_CURRENT_LIST_FILE's basename against every CMAKE_ARGV entry).
# ============================================================================

get_filename_component(_verify_self_name "${CMAKE_CURRENT_LIST_FILE}" NAME)
set(_verify_self_index -1)
set(_verify_i 0)
while(_verify_i LESS CMAKE_ARGC)
    get_filename_component(_verify_argv_name "${CMAKE_ARGV${_verify_i}}" NAME)
    if(_verify_argv_name STREQUAL _verify_self_name)
        set(_verify_self_index ${_verify_i})
    endif()
    math(EXPR _verify_i "${_verify_i}+1")
endwhile()

if(_verify_self_index GREATER -1)
    include("${CMAKE_CURRENT_LIST_DIR}/echo.cmake")

    set(_verify_user_arg_count 0)
    math(EXPR _verify_user_arg_start "${_verify_self_index}+1")
    set(_verify_i ${_verify_user_arg_start})
    while(_verify_i LESS CMAKE_ARGC)
        if(_verify_user_arg_count EQUAL 0)
            set(_verify_name_a "${CMAKE_ARGV${_verify_i}}")
        elseif(_verify_user_arg_count EQUAL 1)
            set(_verify_name_b "${CMAKE_ARGV${_verify_i}}")
        endif()
        math(EXPR _verify_user_arg_count "${_verify_user_arg_count}+1")
        math(EXPR _verify_i "${_verify_i}+1")
    endwhile()

    if(NOT _verify_user_arg_count EQUAL 2)
        message(FATAL_ERROR "usage: cmake -P verify.cmake <frameworkNameOrPath-A> <frameworkNameOrPath-B>\nA name containing '/' is treated as a literal root path instead of a frameworks.md registry lookup.")
    endif()

    _verify_run_comparison("${_verify_name_a}" "${_verify_name_b}")

    execute_process(
        COMMAND git diff --no-index --stat "${_verify_export_a_dir}" "${_verify_export_b_dir}"
        OUTPUT_VARIABLE _verify_diff_stat
        RESULT_VARIABLE _verify_diff_result
    )

    if(_verify_diff_result EQUAL 0)
        message(STATUS "✓ in sync: ${_verify_name_a} <-> ${_verify_name_b}")
    else()
        message(STATUS "${_verify_diff_stat}")
        message(FATAL_ERROR "echo: verify: ${_verify_name_a} and ${_verify_name_b} are out of sync")
    endif()
endif()
