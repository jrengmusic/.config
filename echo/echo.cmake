# echo.cmake
# ============================================================================
# CONFIGURE-TIME MARKDOWN PIPE-TABLE ENGINE
# ============================================================================
#
# Purpose:
#   Parses a Markdown file into an ordered element stream (headings, prose
#   lines, pipe-table rows), classifies each table row's structural role
#   (header / alignment-separator / data) and exposes required-cell lookup
#   by header column name. Carries no knowledge of what a heading or a
#   column name means — callers interpret that.
#
# Public API:
#   echo_table_parse(<file_path> <out_prefix>)
#     Parses one file into `<out_prefix>_*` element-stream variables:
#       <out_prefix>_source
#       <out_prefix>_total
#       <out_prefix>_type_<i>            "heading" | "text" | "row"
#       <out_prefix>_line_<i>
#       <out_prefix>_heading_<i>         (type == heading)
#       <out_prefix>_text_<i>            (type == text)
#       <out_prefix>_row_cell_count_<i>  (type == row)
#       <out_prefix>_row_is_separator_<i>(type == row)
#       <out_prefix>_row_cell_<i>_<j>    (type == row)
#
#   echo_table_section(<doc_prefix> <section_name> <out_prefix>)
#     Extracts the elements between the heading whose text equals
#     <section_name> and the next heading (or end of file), producing
#     `<out_prefix>_*` variables:
#       <out_prefix>_source
#       <out_prefix>_heading_line
#       <out_prefix>_text_total
#       <out_prefix>_text_<k>
#       <out_prefix>_text_line_<k>
#       <out_prefix>_row_total
#       <out_prefix>_row_<k>_role        "header" | "separator" | "data"
#       <out_prefix>_row_<k>_file
#       <out_prefix>_row_<k>_line
#       <out_prefix>_row_<k>_cell_count
#       <out_prefix>_row_<k>_cell_<c>
#       <out_prefix>_row_<k>_column_<name>   (column name -> cell index)
#
#   echo_table_require(<row_prefix> <key> <out_var>)
#     Fetches the cell value named <key> from a row produced above
#     (<row_prefix> = "<section_out_prefix>_row_<k>"). FATAL_ERROR naming
#     the file:line and the missing column when the row carries no such
#     column.
#
#   get_framework_root(<name> <out_var>)
#     Looks up <name> in this file's own frameworks.md "Frameworks" section
#     (framework column), expands a leading "~/" in the matched root via
#     $ENV{HOME}, and returns the result in <out_var>. FATAL_ERROR listing
#     every declared framework name when <name> is not declared.
#
#   echo_identity_load(<file_path> <out_prefix>)
#     Parses the `## Source Identity`, `## Product Identity` (companyWebsite
#     only), and optional `## Module Pairs` and `## Generated Headers`
#     sections of an identity descriptor file into `<out_prefix>_*`
#     variables:
#       <out_prefix>_source
#       <out_prefix>_namespace
#       <out_prefix>_filePrefix
#       <out_prefix>_macroPrefix
#       <out_prefix>_moduleVendor
#       <out_prefix>_companyWebsite
#       <out_prefix>_namespaceShort     (optional — set only when the
#                                        Source Identity declares it)
#       <out_prefix>_pair_total
#       <out_prefix>_pair_<i>_canonical
#       <out_prefix>_pair_<i>_local
#       <out_prefix>_header_total
#       <out_prefix>_header_<i>_canonical
#       <out_prefix>_header_<i>_local
#     FATAL_ERROR naming file:line on a missing mandatory Source Identity
#     key, a missing mandatory Product Identity companyWebsite key, or on a
#     duplicate Source Identity key.
#
#   echo_tokens_forward(<identity_a_prefix> <identity_b_prefix> <text_content> <out_var>)
#     Rewrites <text_content> from identity A's token register to
#     identity B's — generated header names, namespace declaration,
#     qualified-use, macro prefix, file prefix, module vendor, module
#     website, module-pair names, then bare-word namespace occurrences by
#     boundary class, most-specific first.
#
#   echo_tokens_inverse(<identity_a_prefix> <identity_b_prefix> <text_content> <out_var>)
#     Exact inverse of echo_tokens_forward (B -> A), same derivation.
#
#   echo_roundtrip_check(<identity_a_prefix> <identity_b_prefix> <file_path>)
#     Reads <file_path>, applies inverse(forward(content)), FATAL_ERROR
#     naming the file, the first divergent character offset, and a
#     centered excerpt from both strings when the result is not
#     byte-identical to the original.
#
# THREAD: Configuration-time (CMake) — included by table-owning generators.
# ============================================================================

string(ASCII 239 187 191 _echo_bom)

set(_echo_self_dir "${CMAKE_CURRENT_LIST_DIR}")

# ============================================================================
# Cell splitting — manual scan (not CMake list()) so cell content carrying a
# literal ';' cannot be misread as a list separator.
# ============================================================================

function(_echo_split_cells content out_count_var)
    set(_echo_remaining "${content}")
    set(_echo_count 0)
    set(_echo_done 0)
    while(NOT _echo_done)
        string(FIND "${_echo_remaining}" "|" _echo_pipe_pos)
        if(_echo_pipe_pos EQUAL -1)
            string(STRIP "${_echo_remaining}" _echo_cell)
            set(_echo_cell_${_echo_count} "${_echo_cell}" PARENT_SCOPE)
            math(EXPR _echo_count "${_echo_count}+1")
            set(_echo_done 1)
        else()
            string(SUBSTRING "${_echo_remaining}" 0 ${_echo_pipe_pos} _echo_cell)
            string(STRIP "${_echo_cell}" _echo_cell)
            set(_echo_cell_${_echo_count} "${_echo_cell}" PARENT_SCOPE)
            math(EXPR _echo_count "${_echo_count}+1")
            math(EXPR _echo_next_start "${_echo_pipe_pos}+1")
            string(SUBSTRING "${_echo_remaining}" ${_echo_next_start} -1 _echo_remaining)
        endif()
    endwhile()
    set(${out_count_var} "${_echo_count}" PARENT_SCOPE)
endfunction()

# ============================================================================
# Line splitting — same manual-scan shape as cell splitting, on '\n', so a
# literal ';' inside a line is never misread as a list separator either.
# Output goes to <out_prefix>_<i>, mirroring the public API's out_prefix
# pattern so more than one split can coexist in a caller's scope.
# ============================================================================

function(_echo_split_lines content out_prefix out_count_var)
    set(_echo_remaining "${content}")
    set(_echo_count 0)
    set(_echo_done 0)
    while(NOT _echo_done)
        string(FIND "${_echo_remaining}" "\n" _echo_nl_pos)
        if(_echo_nl_pos EQUAL -1)
            set(${out_prefix}_${_echo_count} "${_echo_remaining}" PARENT_SCOPE)
            math(EXPR _echo_count "${_echo_count}+1")
            set(_echo_done 1)
        else()
            string(SUBSTRING "${_echo_remaining}" 0 ${_echo_nl_pos} _echo_line_content)
            set(${out_prefix}_${_echo_count} "${_echo_line_content}" PARENT_SCOPE)
            math(EXPR _echo_count "${_echo_count}+1")
            math(EXPR _echo_next_start "${_echo_nl_pos}+1")
            string(SUBSTRING "${_echo_remaining}" ${_echo_next_start} -1 _echo_remaining)
        endif()
    endwhile()
    set(${out_count_var} "${_echo_count}" PARENT_SCOPE)
endfunction()

# ============================================================================
# echo_table_parse — file read, BOM strip, CRLF/LF normalization, heading and
# table-row classification, one element per source line.
# ============================================================================

function(echo_table_parse file_path out_prefix)
    if(NOT EXISTS "${file_path}")
        message(FATAL_ERROR "echo: input file not found: ${file_path}")
    endif()

    file(READ "${file_path}" _echo_content)

    string(LENGTH "${_echo_content}" _echo_content_len)
    if(_echo_content_len GREATER 2)
        string(SUBSTRING "${_echo_content}" 0 3 _echo_bom_probe)
        if(_echo_bom_probe STREQUAL _echo_bom)
            string(SUBSTRING "${_echo_content}" 3 -1 _echo_content)
        endif()
    endif()

    string(REPLACE "\r\n" "\n" _echo_content "${_echo_content}")
    string(REPLACE "\r" "\n" _echo_content "${_echo_content}")

    string(LENGTH "${_echo_content}" _echo_content_len)
    if(_echo_content_len GREATER 0)
        math(EXPR _echo_last_pos "${_echo_content_len}-1")
        string(SUBSTRING "${_echo_content}" ${_echo_last_pos} 1 _echo_last_char)
        if(_echo_last_char STREQUAL "\n")
            string(SUBSTRING "${_echo_content}" 0 ${_echo_last_pos} _echo_content)
        endif()
    endif()

    set(${out_prefix}_source "${file_path}" PARENT_SCOPE)

    set(_echo_total 0)
    if(NOT "${_echo_content}" STREQUAL "")
        _echo_split_lines("${_echo_content}" _echo_source_line _echo_line_total)

        set(_echo_n 0)
        while(_echo_n LESS _echo_line_total)
            math(EXPR _echo_line_number "${_echo_n}+1")
            string(STRIP "${_echo_source_line_${_echo_n}}" _echo_trimmed)

            if(_echo_trimmed MATCHES "^## (.+)$")
                set(_echo_heading_text "${CMAKE_MATCH_1}")
                string(STRIP "${_echo_heading_text}" _echo_heading_text)
                set(${out_prefix}_type_${_echo_total} "heading" PARENT_SCOPE)
                set(${out_prefix}_line_${_echo_total} "${_echo_line_number}" PARENT_SCOPE)
                set(${out_prefix}_heading_${_echo_total} "${_echo_heading_text}" PARENT_SCOPE)
            elseif(_echo_trimmed MATCHES "^\\|")
                if(NOT _echo_trimmed MATCHES "^\\|(.*)\\|$")
                    message(FATAL_ERROR "echo: ${file_path}:${_echo_line_number}: malformed table row: ${_echo_trimmed}")
                endif()
                set(_echo_row_inner "${CMAKE_MATCH_1}")
                _echo_split_cells("${_echo_row_inner}" _echo_cell_count)

                set(_echo_is_separator 1)
                set(_echo_sep_i 0)
                while(_echo_sep_i LESS _echo_cell_count)
                    if(NOT _echo_cell_${_echo_sep_i} MATCHES "^:?-+:?$")
                        set(_echo_is_separator 0)
                    endif()
                    math(EXPR _echo_sep_i "${_echo_sep_i}+1")
                endwhile()

                set(${out_prefix}_type_${_echo_total} "row" PARENT_SCOPE)
                set(${out_prefix}_line_${_echo_total} "${_echo_line_number}" PARENT_SCOPE)
                set(${out_prefix}_row_cell_count_${_echo_total} "${_echo_cell_count}" PARENT_SCOPE)
                set(${out_prefix}_row_is_separator_${_echo_total} "${_echo_is_separator}" PARENT_SCOPE)

                set(_echo_cell_i 0)
                while(_echo_cell_i LESS _echo_cell_count)
                    set(${out_prefix}_row_cell_${_echo_total}_${_echo_cell_i} "${_echo_cell_${_echo_cell_i}}" PARENT_SCOPE)
                    math(EXPR _echo_cell_i "${_echo_cell_i}+1")
                endwhile()
            else()
                set(${out_prefix}_type_${_echo_total} "text" PARENT_SCOPE)
                set(${out_prefix}_line_${_echo_total} "${_echo_line_number}" PARENT_SCOPE)
                set(${out_prefix}_text_${_echo_total} "${_echo_trimmed}" PARENT_SCOPE)
            endif()

            math(EXPR _echo_total "${_echo_total}+1")
            math(EXPR _echo_n "${_echo_n}+1")
        endwhile()
    endif()

    set(${out_prefix}_total "${_echo_total}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _echo_register_column — per-table duplicate column-key detection backing
# echo_table_section's header parse.
# ============================================================================

function(_echo_register_column registry_prefix key index file line)
    if(DEFINED ${registry_prefix}_${key})
        message(FATAL_ERROR "echo: ${file}:${line}: duplicate column '${key}' in table header")
    endif()
    set(${registry_prefix}_${key} "${index}" PARENT_SCOPE)
endfunction()

# ============================================================================
# echo_table_section — one heading's elements: prose text, and rows tagged
# header / separator / data. Header cell text becomes each row's column
# name -> index map, consumed by echo_table_require.
# ============================================================================

function(echo_table_section doc_prefix section_name out_prefix)
    set(_echo_source "${${doc_prefix}_source}")
    set(_echo_total "${${doc_prefix}_total}")

    set(_echo_heading_index -1)
    set(_echo_i 0)
    while(_echo_i LESS _echo_total AND _echo_heading_index EQUAL -1)
        if("${${doc_prefix}_type_${_echo_i}}" STREQUAL "heading" AND "${${doc_prefix}_heading_${_echo_i}}" STREQUAL "${section_name}")
            set(_echo_heading_index ${_echo_i})
        endif()
        math(EXPR _echo_i "${_echo_i}+1")
    endwhile()
    if(_echo_heading_index EQUAL -1)
        message(FATAL_ERROR "echo: ${_echo_source}: section '${section_name}' not found")
    endif()

    set(_echo_end ${_echo_total})
    set(_echo_end_found 0)
    set(_echo_scan ${_echo_heading_index})
    math(EXPR _echo_scan "${_echo_scan}+1")
    while(_echo_scan LESS _echo_total AND NOT _echo_end_found)
        if("${${doc_prefix}_type_${_echo_scan}}" STREQUAL "heading")
            set(_echo_end ${_echo_scan})
            set(_echo_end_found 1)
        endif()
        math(EXPR _echo_scan "${_echo_scan}+1")
    endwhile()

    set(${out_prefix}_source "${_echo_source}" PARENT_SCOPE)
    set(${out_prefix}_heading_line "${${doc_prefix}_line_${_echo_heading_index}}" PARENT_SCOPE)

    set(_echo_text_total 0)
    set(_echo_row_total 0)
    set(_echo_header_seen 0)
    set(_echo_header_cell_count 0)

    set(_echo_j ${_echo_heading_index})
    math(EXPR _echo_j "${_echo_j}+1")
    while(_echo_j LESS _echo_end)
        set(_echo_type "${${doc_prefix}_type_${_echo_j}}")
        set(_echo_line "${${doc_prefix}_line_${_echo_j}}")

        if(_echo_type STREQUAL "text")
            set(${out_prefix}_text_${_echo_text_total} "${${doc_prefix}_text_${_echo_j}}" PARENT_SCOPE)
            set(${out_prefix}_text_line_${_echo_text_total} "${_echo_line}" PARENT_SCOPE)
            math(EXPR _echo_text_total "${_echo_text_total}+1")
        elseif(_echo_type STREQUAL "row")
            set(_echo_cell_count "${${doc_prefix}_row_cell_count_${_echo_j}}")
            set(_echo_is_separator "${${doc_prefix}_row_is_separator_${_echo_j}}")

            if(_echo_is_separator)
                set(_echo_role "separator")
            elseif(NOT _echo_header_seen)
                set(_echo_role "header")
            else()
                if(NOT _echo_cell_count EQUAL _echo_header_cell_count)
                    message(FATAL_ERROR "echo: ${_echo_source}:${_echo_line}: table row has ${_echo_cell_count} cell(s), header has ${_echo_header_cell_count}")
                endif()
                set(_echo_role "data")
            endif()

            set(_echo_k ${_echo_row_total})
            set(${out_prefix}_row_${_echo_k}_role "${_echo_role}" PARENT_SCOPE)
            set(${out_prefix}_row_${_echo_k}_file "${_echo_source}" PARENT_SCOPE)
            set(${out_prefix}_row_${_echo_k}_line "${_echo_line}" PARENT_SCOPE)
            set(${out_prefix}_row_${_echo_k}_cell_count "${_echo_cell_count}" PARENT_SCOPE)

            set(_echo_c 0)
            while(_echo_c LESS _echo_cell_count)
                set(_echo_cell_value "${${doc_prefix}_row_cell_${_echo_j}_${_echo_c}}")
                set(${out_prefix}_row_${_echo_k}_cell_${_echo_c} "${_echo_cell_value}" PARENT_SCOPE)
                if(_echo_role STREQUAL "header")
                    _echo_register_column(_echo_columns "${_echo_cell_value}" "${_echo_c}" "${_echo_source}" "${_echo_line}")
                    set(_echo_column_name_${_echo_c} "${_echo_cell_value}")
                endif()
                math(EXPR _echo_c "${_echo_c}+1")
            endwhile()

            if(_echo_role STREQUAL "header")
                set(_echo_header_seen 1)
                set(_echo_header_cell_count "${_echo_cell_count}")
            endif()

            math(EXPR _echo_row_total "${_echo_row_total}+1")
        endif()

        math(EXPR _echo_j "${_echo_j}+1")
    endwhile()

    set(${out_prefix}_text_total "${_echo_text_total}" PARENT_SCOPE)
    set(${out_prefix}_row_total "${_echo_row_total}" PARENT_SCOPE)

    set(_echo_k 0)
    while(_echo_k LESS _echo_row_total)
        set(_echo_c 0)
        while(_echo_c LESS _echo_header_cell_count)
            set(${out_prefix}_row_${_echo_k}_column_${_echo_column_name_${_echo_c}} "${_echo_c}" PARENT_SCOPE)
            math(EXPR _echo_c "${_echo_c}+1")
        endwhile()
        math(EXPR _echo_k "${_echo_k}+1")
    endwhile()
endfunction()

# ============================================================================
# echo_table_require — required cell access by header column name.
# ============================================================================

function(echo_table_require row_prefix key out_var)
    if(NOT DEFINED ${row_prefix}_column_${key})
        message(FATAL_ERROR "echo: ${${row_prefix}_file}:${${row_prefix}_line}: required column '${key}' not present")
    endif()
    set(_echo_require_index "${${row_prefix}_column_${key}}")
    set(${out_var} "${${row_prefix}_cell_${_echo_require_index}}" PARENT_SCOPE)
endfunction()

# ============================================================================
# get_framework_root — resolves a declared framework name to its root path
# via this file's own frameworks.md "Frameworks" section, expanding a
# leading "~/" through $ENV{HOME}.
# ============================================================================

function(get_framework_root name out_var)
    echo_table_parse("${_echo_self_dir}/frameworks.md" _echo_gfr_doc)
    echo_table_section(_echo_gfr_doc "Frameworks" _echo_gfr_section)

    set(_echo_gfr_declared_names "")
    set(_echo_gfr_root_found 0)

    set(_echo_gfr_k 0)
    while(_echo_gfr_k LESS _echo_gfr_section_row_total)
        if(_echo_gfr_section_row_${_echo_gfr_k}_role STREQUAL "data")
            echo_table_require(_echo_gfr_section_row_${_echo_gfr_k} "framework" _echo_gfr_row_framework)
            echo_table_require(_echo_gfr_section_row_${_echo_gfr_k} "root" _echo_gfr_row_root)
            list(APPEND _echo_gfr_declared_names "${_echo_gfr_row_framework}")
            if(_echo_gfr_row_framework STREQUAL name)
                set(_echo_gfr_root "${_echo_gfr_row_root}")
                set(_echo_gfr_root_found 1)
            endif()
        endif()
        math(EXPR _echo_gfr_k "${_echo_gfr_k}+1")
    endwhile()

    if(NOT _echo_gfr_root_found)
        string(JOIN ", " _echo_gfr_declared_joined ${_echo_gfr_declared_names})
        message(FATAL_ERROR "echo: unknown framework '${name}'. Declared frameworks: ${_echo_gfr_declared_joined}")
    endif()

    string(FIND "${_echo_gfr_root}" "~/" _echo_gfr_tilde_pos)
    if(_echo_gfr_tilde_pos EQUAL 0)
        string(SUBSTRING "${_echo_gfr_root}" 2 -1 _echo_gfr_root_remainder)
        set(_echo_gfr_root "$ENV{HOME}/${_echo_gfr_root_remainder}")
    endif()

    set(${out_var} "${_echo_gfr_root}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _echo_regex_escape — escapes CMake ERE metacharacters so a data value can
# be embedded literally inside a REGEX pattern.
# ============================================================================

function(_echo_regex_escape input_value out_var)
    string(REGEX REPLACE "([].[*+?^$(){}|\\\\])" "\\\\\\1" _echo_escaped "${input_value}")
    set(${out_var} "${_echo_escaped}" PARENT_SCOPE)
endfunction()

# ============================================================================
# echo_identity_load — Source Identity + Module Pairs + Generated Headers
# sections of an identity descriptor file, dogfooding
# echo_table_parse/echo_table_section.
# ============================================================================

function(echo_identity_load file_path out_prefix)
    echo_table_parse("${file_path}" _echo_id_doc)
    echo_table_section(_echo_id_doc "Source Identity" _echo_id_identity)

    set(_echo_id_namespace_set 0)
    set(_echo_id_filePrefix_set 0)
    set(_echo_id_macroPrefix_set 0)
    set(_echo_id_moduleVendor_set 0)

    set(_echo_id_i 0)
    while(_echo_id_i LESS _echo_id_identity_row_total)
        if(_echo_id_identity_row_${_echo_id_i}_role STREQUAL "data")
            echo_table_require(_echo_id_identity_row_${_echo_id_i} "key" _echo_id_key)
            echo_table_require(_echo_id_identity_row_${_echo_id_i} "value" _echo_id_value)
            set(_echo_id_file "${_echo_id_identity_row_${_echo_id_i}_file}")
            set(_echo_id_line "${_echo_id_identity_row_${_echo_id_i}_line}")

            if(DEFINED _echo_id_key_loc_${_echo_id_key})
                message(FATAL_ERROR "echo: ${_echo_id_file}:${_echo_id_line}: duplicate Source Identity key '${_echo_id_key}' (also declared at ${_echo_id_key_loc_${_echo_id_key}})")
            endif()
            set(_echo_id_key_loc_${_echo_id_key} "${_echo_id_file}:${_echo_id_line}")

            if(_echo_id_key STREQUAL "namespace")
                set(${out_prefix}_namespace "${_echo_id_value}" PARENT_SCOPE)
                set(_echo_id_namespace_set 1)
            elseif(_echo_id_key STREQUAL "filePrefix")
                set(${out_prefix}_filePrefix "${_echo_id_value}" PARENT_SCOPE)
                set(_echo_id_filePrefix_set 1)
            elseif(_echo_id_key STREQUAL "macroPrefix")
                set(${out_prefix}_macroPrefix "${_echo_id_value}" PARENT_SCOPE)
                set(_echo_id_macroPrefix_set 1)
            elseif(_echo_id_key STREQUAL "moduleVendor")
                set(${out_prefix}_moduleVendor "${_echo_id_value}" PARENT_SCOPE)
                set(_echo_id_moduleVendor_set 1)
            elseif(_echo_id_key STREQUAL "namespaceShort")
                set(${out_prefix}_namespaceShort "${_echo_id_value}" PARENT_SCOPE)
            endif()
        endif()
        math(EXPR _echo_id_i "${_echo_id_i}+1")
    endwhile()

    if(NOT _echo_id_namespace_set)
        message(FATAL_ERROR "echo: ${file_path}:${_echo_id_identity_heading_line}: Source Identity missing mandatory key 'namespace'")
    endif()
    if(NOT _echo_id_filePrefix_set)
        message(FATAL_ERROR "echo: ${file_path}:${_echo_id_identity_heading_line}: Source Identity missing mandatory key 'filePrefix'")
    endif()
    if(NOT _echo_id_macroPrefix_set)
        message(FATAL_ERROR "echo: ${file_path}:${_echo_id_identity_heading_line}: Source Identity missing mandatory key 'macroPrefix'")
    endif()
    if(NOT _echo_id_moduleVendor_set)
        message(FATAL_ERROR "echo: ${file_path}:${_echo_id_identity_heading_line}: Source Identity missing mandatory key 'moduleVendor'")
    endif()

    echo_table_section(_echo_id_doc "Product Identity" _echo_id_product)

    set(_echo_id_companyWebsite_set 0)
    set(_echo_id_k 0)
    while(_echo_id_k LESS _echo_id_product_row_total)
        if(_echo_id_product_row_${_echo_id_k}_role STREQUAL "data")
            echo_table_require(_echo_id_product_row_${_echo_id_k} "key" _echo_id_product_key)
            if(_echo_id_product_key STREQUAL "companyWebsite")
                echo_table_require(_echo_id_product_row_${_echo_id_k} "value" _echo_id_product_value)
                set(${out_prefix}_companyWebsite "${_echo_id_product_value}" PARENT_SCOPE)
                set(_echo_id_companyWebsite_set 1)
            endif()
        endif()
        math(EXPR _echo_id_k "${_echo_id_k}+1")
    endwhile()

    if(NOT _echo_id_companyWebsite_set)
        message(FATAL_ERROR "echo: ${file_path}:${_echo_id_product_heading_line}: Product Identity missing mandatory key 'companyWebsite'")
    endif()

    set(_echo_id_pairs_present 0)
    set(_echo_id_j 0)
    while(_echo_id_j LESS _echo_id_doc_total)
        if(_echo_id_doc_type_${_echo_id_j} STREQUAL "heading" AND _echo_id_doc_heading_${_echo_id_j} STREQUAL "Module Pairs")
            set(_echo_id_pairs_present 1)
        endif()
        math(EXPR _echo_id_j "${_echo_id_j}+1")
    endwhile()

    set(_echo_id_pair_total 0)
    if(_echo_id_pairs_present)
        echo_table_section(_echo_id_doc "Module Pairs" _echo_id_pairs)

        set(_echo_id_k 0)
        while(_echo_id_k LESS _echo_id_pairs_row_total)
            if(_echo_id_pairs_row_${_echo_id_k}_role STREQUAL "data")
                echo_table_require(_echo_id_pairs_row_${_echo_id_k} "canonical" _echo_id_canonical)
                echo_table_require(_echo_id_pairs_row_${_echo_id_k} "local" _echo_id_local)
                set(${out_prefix}_pair_${_echo_id_pair_total}_canonical "${_echo_id_canonical}" PARENT_SCOPE)
                set(${out_prefix}_pair_${_echo_id_pair_total}_local "${_echo_id_local}" PARENT_SCOPE)
                math(EXPR _echo_id_pair_total "${_echo_id_pair_total}+1")
            endif()
            math(EXPR _echo_id_k "${_echo_id_k}+1")
        endwhile()
    endif()

    set(${out_prefix}_pair_total "${_echo_id_pair_total}" PARENT_SCOPE)

    set(_echo_id_headers_present 0)
    set(_echo_id_j 0)
    while(_echo_id_j LESS _echo_id_doc_total)
        if(_echo_id_doc_type_${_echo_id_j} STREQUAL "heading" AND _echo_id_doc_heading_${_echo_id_j} STREQUAL "Generated Headers")
            set(_echo_id_headers_present 1)
        endif()
        math(EXPR _echo_id_j "${_echo_id_j}+1")
    endwhile()

    set(_echo_id_header_total 0)
    if(_echo_id_headers_present)
        echo_table_section(_echo_id_doc "Generated Headers" _echo_id_headers)

        set(_echo_id_k 0)
        while(_echo_id_k LESS _echo_id_headers_row_total)
            if(_echo_id_headers_row_${_echo_id_k}_role STREQUAL "data")
                echo_table_require(_echo_id_headers_row_${_echo_id_k} "canonical" _echo_id_header_canonical)
                echo_table_require(_echo_id_headers_row_${_echo_id_k} "local" _echo_id_header_local)
                set(${out_prefix}_header_${_echo_id_header_total}_canonical "${_echo_id_header_canonical}" PARENT_SCOPE)
                set(${out_prefix}_header_${_echo_id_header_total}_local "${_echo_id_header_local}" PARENT_SCOPE)
                math(EXPR _echo_id_header_total "${_echo_id_header_total}+1")
            endif()
            math(EXPR _echo_id_k "${_echo_id_k}+1")
        endwhile()
    endif()

    set(${out_prefix}_header_total "${_echo_id_header_total}" PARENT_SCOPE)
    set(${out_prefix}_source "${file_path}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _echo_find_table_local — canonical-key lookup of a Module Pairs or
# Generated Headers local name within a loaded identity, backing the
# module-pair and generated-header steps of token transform. <table_kind> is
# "pair" or "header", selecting which `<identity_prefix>_<table_kind>_*`
# register to search.
# ============================================================================

function(_echo_find_table_local identity_prefix table_kind canonical out_local_var out_found_var)
    set(_echo_found 0)
    set(_echo_local "")
    set(_echo_i 0)
    while(_echo_i LESS ${identity_prefix}_${table_kind}_total AND NOT _echo_found)
        if("${${identity_prefix}_${table_kind}_${_echo_i}_canonical}" STREQUAL "${canonical}")
            set(_echo_local "${${identity_prefix}_${table_kind}_${_echo_i}_local}")
            set(_echo_found 1)
        endif()
        math(EXPR _echo_i "${_echo_i}+1")
    endwhile()
    set(${out_local_var} "${_echo_local}" PARENT_SCOPE)
    set(${out_found_var} "${_echo_found}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _echo_apply_bare_word_token — boundary-class bare-word substitution: a
# non-word/non-digit/non-underscore boundary on both sides, applied
# repeatedly until stable (adjacent tokens share a single boundary
# character, so one pass alone misses overlaps), plus anchored
# string-start and string-end variants for a token touching a text edge.
# ============================================================================

function(_echo_apply_bare_word_token from_token to_token text_content out_var)
    _echo_regex_escape("${from_token}" _echo_from_escaped)
    set(_echo_result "${text_content}")

    set(_echo_stable 0)
    while(NOT _echo_stable)
        set(_echo_before "${_echo_result}")
        string(REGEX REPLACE "([^a-zA-Z0-9_])${_echo_from_escaped}([^a-zA-Z0-9_])" "\\1${to_token}\\2" _echo_result "${_echo_result}")
        if(_echo_result STREQUAL _echo_before)
            set(_echo_stable 1)
        endif()
    endwhile()

    string(REGEX REPLACE "^${_echo_from_escaped}([^a-zA-Z0-9_])" "${to_token}\\1" _echo_result "${_echo_result}")
    string(REGEX REPLACE "([^a-zA-Z0-9_])${_echo_from_escaped}$" "\\1${to_token}" _echo_result "${_echo_result}")

    set(${out_var} "${_echo_result}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _echo_tokens_transform — shared derivation for echo_tokens_forward and
# echo_tokens_inverse: ordered literal replacements (generated header
# names, namespace declaration, qualified-use, macro prefix, file prefix,
# module vendor, module website, module-pair names) most-specific first,
# then the bare-word namespace token last. Generated header names run
# before every other literal step — they are the longest literals and can
# embed a shorter token (e.g. the module vendor word), so mapping them
# first prevents a later, shorter-literal step from partially matching
# inside an as-yet-unmapped header name. Vendor and website are
# field-anchored (only their own declaration-block field) and run before
# the bare-word namespace step for the same reason: the source
# vendor/website value can equal the source namespace value, so the
# field-anchored steps must claim their own field first or the broad
# namespace sweep would substitute the wrong target value there.
# ============================================================================

function(_echo_tokens_transform from_prefix to_prefix text_content out_var)
    set(_echo_result "${text_content}")

    set(_echo_header_i 0)
    while(_echo_header_i LESS ${from_prefix}_header_total)
        set(_echo_header_canonical "${${from_prefix}_header_${_echo_header_i}_canonical}")
        set(_echo_header_from_local "${${from_prefix}_header_${_echo_header_i}_local}")
        _echo_find_table_local("${to_prefix}" header "${_echo_header_canonical}" _echo_header_to_local _echo_header_found)
        if(_echo_header_found)
            string(REPLACE "${_echo_header_from_local}" "${_echo_header_to_local}" _echo_result "${_echo_result}")
        endif()
        math(EXPR _echo_header_i "${_echo_header_i}+1")
    endwhile()

    string(REPLACE "namespace ${${from_prefix}_namespace}" "namespace ${${to_prefix}_namespace}" _echo_result "${_echo_result}")
    string(REPLACE "${${from_prefix}_namespace}::" "${${to_prefix}_namespace}::" _echo_result "${_echo_result}")
    string(REPLACE "${${from_prefix}_macroPrefix}" "${${to_prefix}_macroPrefix}" _echo_result "${_echo_result}")
    string(REPLACE "${${from_prefix}_filePrefix}" "${${to_prefix}_filePrefix}" _echo_result "${_echo_result}")
    # vendor lives solely in JUCE module declaration blocks; identical bytes
    # elsewhere are kernel data. The field name and colon may carry
    # column-alignment padding on either side; that padding is captured
    # into the replacement group unchanged, only the value substitutes.
    _echo_regex_escape("${${from_prefix}_moduleVendor}" _echo_vendor_from_escaped)
    string(REGEX REPLACE "(vendor[ \t]*:[ \t]*)${_echo_vendor_from_escaped}" "\\1${${to_prefix}_moduleVendor}" _echo_result "${_echo_result}")
    # website lives solely in JUCE module declaration blocks, same
    # whitespace-tolerant, padding-preserving mechanics as vendor above.
    _echo_regex_escape("${${from_prefix}_companyWebsite}" _echo_website_from_escaped)
    string(REGEX REPLACE "(website[ \t]*:[ \t]*)${_echo_website_from_escaped}" "\\1${${to_prefix}_companyWebsite}" _echo_result "${_echo_result}")

    set(_echo_pair_i 0)
    while(_echo_pair_i LESS ${from_prefix}_pair_total)
        set(_echo_pair_canonical "${${from_prefix}_pair_${_echo_pair_i}_canonical}")
        set(_echo_pair_from_local "${${from_prefix}_pair_${_echo_pair_i}_local}")
        _echo_find_table_local("${to_prefix}" pair "${_echo_pair_canonical}" _echo_pair_to_local _echo_pair_found)
        if(_echo_pair_found)
            string(REPLACE "${_echo_pair_from_local}" "${_echo_pair_to_local}" _echo_result "${_echo_result}")
        endif()
        math(EXPR _echo_pair_i "${_echo_pair_i}+1")
    endwhile()

    _echo_apply_bare_word_token("${${from_prefix}_namespace}" "${${to_prefix}_namespace}" "${_echo_result}" _echo_result)

    set(${out_var} "${_echo_result}" PARENT_SCOPE)
endfunction()

# ============================================================================
# echo_tokens_forward / echo_tokens_inverse — one derivation helper, two
# argument orders (B -> A is the exact inverse of A -> B).
# ============================================================================

function(echo_tokens_forward identity_a_prefix identity_b_prefix text_content out_var)
    _echo_tokens_transform("${identity_a_prefix}" "${identity_b_prefix}" "${text_content}" _echo_forward_result)
    set(${out_var} "${_echo_forward_result}" PARENT_SCOPE)
endfunction()

function(echo_tokens_inverse identity_a_prefix identity_b_prefix text_content out_var)
    _echo_tokens_transform("${identity_b_prefix}" "${identity_a_prefix}" "${text_content}" _echo_inverse_result)
    set(${out_var} "${_echo_inverse_result}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _echo_first_diff_offset — largest common-prefix length of two strings via
# a bisection over string(SUBSTRING) equality (no regex): the offset where
# the strings first diverge, or the shorter string's length when one is a
# strict prefix of the other.
# ============================================================================

function(_echo_first_diff_offset a b out_offset_var)
    string(LENGTH "${a}" _echo_len_a)
    string(LENGTH "${b}" _echo_len_b)
    if(_echo_len_a LESS _echo_len_b)
        set(_echo_min_len "${_echo_len_a}")
    else()
        set(_echo_min_len "${_echo_len_b}")
    endif()

    set(_echo_lo 0)
    set(_echo_hi "${_echo_min_len}")
    while(_echo_lo LESS _echo_hi)
        math(EXPR _echo_mid "(${_echo_lo}+${_echo_hi}+1)/2")
        string(SUBSTRING "${a}" 0 ${_echo_mid} _echo_prefix_a)
        string(SUBSTRING "${b}" 0 ${_echo_mid} _echo_prefix_b)
        if(_echo_prefix_a STREQUAL _echo_prefix_b)
            set(_echo_lo "${_echo_mid}")
        else()
            math(EXPR _echo_hi "${_echo_mid}-1")
        endif()
    endwhile()

    set(${out_offset_var} "${_echo_lo}" PARENT_SCOPE)
endfunction()

# ============================================================================
# _echo_centered_excerpt — up to 20 characters on each side of <offset>
# within <content>, clipped to the string bounds, via string(SUBSTRING).
# ============================================================================

function(_echo_centered_excerpt content offset out_excerpt_var)
    string(LENGTH "${content}" _echo_excerpt_len)

    math(EXPR _echo_excerpt_start "${offset}-20")
    if(_echo_excerpt_start LESS 0)
        set(_echo_excerpt_start 0)
    endif()

    math(EXPR _echo_excerpt_end "${offset}+20")
    if(_echo_excerpt_end GREATER _echo_excerpt_len)
        set(_echo_excerpt_end "${_echo_excerpt_len}")
    endif()

    math(EXPR _echo_excerpt_count "${_echo_excerpt_end}-${_echo_excerpt_start}")
    string(SUBSTRING "${content}" ${_echo_excerpt_start} ${_echo_excerpt_count} _echo_excerpt)

    set(${out_excerpt_var} "${_echo_excerpt}" PARENT_SCOPE)
endfunction()

# ============================================================================
# echo_roundtrip_check — inverse(forward(content)) against the original
# file content, byte-for-byte.
# ============================================================================

function(echo_roundtrip_check identity_a_prefix identity_b_prefix file_path)
    file(READ "${file_path}" _echo_roundtrip_original)
    echo_tokens_forward("${identity_a_prefix}" "${identity_b_prefix}" "${_echo_roundtrip_original}" _echo_roundtrip_forward)
    echo_tokens_inverse("${identity_a_prefix}" "${identity_b_prefix}" "${_echo_roundtrip_forward}" _echo_roundtrip_back)
    if(NOT _echo_roundtrip_back STREQUAL _echo_roundtrip_original)
        _echo_first_diff_offset("${_echo_roundtrip_original}" "${_echo_roundtrip_back}" _echo_roundtrip_offset)
        _echo_centered_excerpt("${_echo_roundtrip_original}" "${_echo_roundtrip_offset}" _echo_roundtrip_excerpt_original)
        _echo_centered_excerpt("${_echo_roundtrip_back}" "${_echo_roundtrip_offset}" _echo_roundtrip_excerpt_back)
        message(FATAL_ERROR "echo: roundtrip mismatch: ${file_path} (first divergence at offset ${_echo_roundtrip_offset})\n  original:      ...${_echo_roundtrip_excerpt_original}...\n  round-tripped: ...${_echo_roundtrip_excerpt_back}...")
    endif()
endfunction()
