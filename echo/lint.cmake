get_filename_component(_lint_self_name "${CMAKE_CURRENT_LIST_FILE}" NAME)
set(_lint_self_index -1)
set(_lint_i 0)
while(_lint_i LESS CMAKE_ARGC)
    get_filename_component(_lint_argv_name "${CMAKE_ARGV${_lint_i}}" NAME)
    if(_lint_argv_name STREQUAL _lint_self_name)
        set(_lint_self_index ${_lint_i})
    endif()
    math(EXPR _lint_i "${_lint_i}+1")
endwhile()

if(_lint_self_index EQUAL -1)
    message(FATAL_ERROR "echo: lint: unable to locate own script path among invocation arguments")
endif()

set(_lint_user_arg_count 0)
math(EXPR _lint_user_arg_start "${_lint_self_index}+1")
set(_lint_i ${_lint_user_arg_start})
while(_lint_i LESS CMAKE_ARGC)
    if(_lint_user_arg_count EQUAL 0)
        set(_lint_framework_name "${CMAKE_ARGV${_lint_i}}")
    endif()
    math(EXPR _lint_user_arg_count "${_lint_user_arg_count}+1")
    math(EXPR _lint_i "${_lint_i}+1")
endwhile()

if(NOT _lint_user_arg_count EQUAL 1)
    message(FATAL_ERROR "usage: cmake -P lint.cmake <frameworkName>")
endif()

include("${CMAKE_CURRENT_LIST_DIR}/verify.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/echo.cmake")

get_framework_root("${_lint_framework_name}" _lint_resolved_root)

if(NOT IS_DIRECTORY "${_lint_resolved_root}")
    message(FATAL_ERROR "echo: lint: framework root does not exist: ${_lint_resolved_root}")
endif()

# CHECK 1 — identity file

set(_lint_identity_path "${_lint_resolved_root}/lexicon/identity.md")

if(NOT EXISTS "${_lint_identity_path}")
    message(FATAL_ERROR "echo: lint: CHECK 1 failed: missing ${_lint_identity_path}")
endif()

echo_identity_load("${_lint_identity_path}" _lint_identity)

echo_table_parse("${_lint_identity_path}" _lint_identity_doc)
echo_table_section(_lint_identity_doc "Product Identity" _lint_product_identity)
echo_table_section(_lint_identity_doc "Modules" _lint_modules)

message(STATUS "✓ CHECK 1: identity.md loaded (Source Identity, Product Identity, Modules)")

# CHECK 2 — module classes coherent

set(_lint_check2_findings "")
set(_lint_declared_module_names "")

set(_lint_k 0)
while(_lint_k LESS _lint_modules_row_total)
    if(_lint_modules_row_${_lint_k}_role STREQUAL "data")
        echo_table_require(_lint_modules_row_${_lint_k} "module" _lint_module_name)
        echo_table_require(_lint_modules_row_${_lint_k} "class" _lint_module_class)
        set(_lint_module_file "${_lint_modules_row_${_lint_k}_file}")
        set(_lint_module_line "${_lint_modules_row_${_lint_k}_line}")

        list(APPEND _lint_declared_module_names "${_lint_module_name}")

        if(NOT _lint_module_class STREQUAL "kernel" AND NOT _lint_module_class STREQUAL "provision")
            list(APPEND _lint_check2_findings "${_lint_module_file}:${_lint_module_line}: module '${_lint_module_name}' has invalid class '${_lint_module_class}'")
        endif()

        if(NOT IS_DIRECTORY "${_lint_resolved_root}/${_lint_module_name}")
            list(APPEND _lint_check2_findings "${_lint_module_file}:${_lint_module_line}: declared module '${_lint_module_name}' has no directory ${_lint_resolved_root}/${_lint_module_name}/")
        endif()
    endif()
    math(EXPR _lint_k "${_lint_k}+1")
endwhile()

file(GLOB _lint_disk_candidates LIST_DIRECTORIES true "${_lint_resolved_root}/${_lint_identity_filePrefix}*")
foreach(_lint_candidate ${_lint_disk_candidates})
    if(IS_DIRECTORY "${_lint_candidate}")
        get_filename_component(_lint_candidate_name "${_lint_candidate}" NAME)
        list(FIND _lint_declared_module_names "${_lint_candidate_name}" _lint_candidate_declared_index)
        if(_lint_candidate_declared_index EQUAL -1)
            list(APPEND _lint_check2_findings "${_lint_candidate}: directory not declared in Modules table")
        endif()
    endif()
endforeach()

if(_lint_check2_findings)
    string(JOIN "\n" _lint_check2_message ${_lint_check2_findings})
    message(FATAL_ERROR "echo: lint: CHECK 2 failed:\n${_lint_check2_message}")
endif()

message(STATUS "✓ CHECK 2: module classes coherent")

# ============================================================================
# _lint_mask_declared_headers — replaces every occurrence of each name in
# <header_locals> (a Generated Headers local-name list) inside <line_content>
# with a same-length run of <mask_char>, so a declared header's own local
# name can never register as a Tier-1 literal hit. Filler length is derived
# from each name's own string(LENGTH), never a literal count.
# ============================================================================

function(_lint_mask_declared_headers line_content header_locals mask_char out_var)
    set(_lint_masked_line "${line_content}")
    foreach(_lint_header_local IN LISTS header_locals)
        string(LENGTH "${_lint_header_local}" _lint_header_local_len)
        if(_lint_header_local_len GREATER 0)
            string(REPEAT "${mask_char}" ${_lint_header_local_len} _lint_header_filler)
            string(REPLACE "${_lint_header_local}" "${_lint_header_filler}" _lint_masked_line "${_lint_masked_line}")
        endif()
    endforeach()
    set(${out_var} "${_lint_masked_line}" PARENT_SCOPE)
endfunction()

# CHECK 3 — Tier-1 literal scan

set(_lint_check3_findings "")
set(_lint_tier1_values "")

set(_lint_k 0)
while(_lint_k LESS _lint_product_identity_row_total)
    if(_lint_product_identity_row_${_lint_k}_role STREQUAL "data")
        echo_table_require(_lint_product_identity_row_${_lint_k} "key" _lint_product_key)
        echo_table_require(_lint_product_identity_row_${_lint_k} "value" _lint_product_value)
        if(_lint_product_key STREQUAL "companyName"
            OR _lint_product_key STREQUAL "bundleDomain"
            OR _lint_product_key STREQUAL "manufacturerCode"
            OR _lint_product_key STREQUAL "companyWebsite")
            list(APPEND _lint_tier1_values "${_lint_product_value}")
        endif()
    endif()
    math(EXPR _lint_k "${_lint_k}+1")
endwhile()

set(_lint_declared_header_locals "")
set(_lint_k 0)
while(_lint_k LESS _lint_identity_header_total)
    list(APPEND _lint_declared_header_locals "${_lint_identity_header_${_lint_k}_local}")
    math(EXPR _lint_k "${_lint_k}+1")
endwhile()

string(ASCII 31 _lint_check3_mask_char)

file(GLOB_RECURSE _lint_cmake_files "${_lint_resolved_root}/cmake/*.cmake")

foreach(_lint_cmake_file ${_lint_cmake_files})
    file(READ "${_lint_cmake_file}" _lint_file_content)
    string(REPLACE "\r\n" "\n" _lint_file_content "${_lint_file_content}")
    _echo_split_lines("${_lint_file_content}" _lint_source_line _lint_file_line_total)

    set(_lint_line_i 0)
    while(_lint_line_i LESS _lint_file_line_total)
        set(_lint_line_content "${_lint_source_line_${_lint_line_i}}")
        math(EXPR _lint_line_number "${_lint_line_i}+1")

        string(STRIP "${_lint_line_content}" _lint_stripped_line)
        set(_lint_is_comment 0)
        string(LENGTH "${_lint_stripped_line}" _lint_stripped_len)
        if(_lint_stripped_len GREATER 0)
            string(SUBSTRING "${_lint_stripped_line}" 0 1 _lint_first_char)
            if(_lint_first_char STREQUAL "#")
                set(_lint_is_comment 1)
            endif()
        endif()

        if(NOT _lint_is_comment)
            _lint_mask_declared_headers("${_lint_line_content}" "${_lint_declared_header_locals}" "${_lint_check3_mask_char}" _lint_scan_line)
            foreach(_lint_tier1_value ${_lint_tier1_values})
                string(FIND "${_lint_scan_line}" "${_lint_tier1_value}" _lint_hit_pos)
                if(NOT _lint_hit_pos EQUAL -1)
                    list(APPEND _lint_check3_findings "${_lint_cmake_file}:${_lint_line_number}: ${_lint_tier1_value}")
                endif()
            endforeach()
        endif()

        math(EXPR _lint_line_i "${_lint_line_i}+1")
    endwhile()
endforeach()

if(_lint_check3_findings)
    string(JOIN "\n" _lint_check3_message ${_lint_check3_findings})
    message(FATAL_ERROR "echo: lint: CHECK 3 failed:\n${_lint_check3_message}")
endif()

message(STATUS "✓ CHECK 3: Tier-1 literal scan clean")

# CHECK 4 — Sync Ignore patterns

set(_lint_check4_findings "")

echo_table_section(_lint_identity_doc "Sync Ignore" _lint_sync_ignore)

set(_lint_check4_in_fence 0)

set(_lint_k 0)
while(_lint_k LESS _lint_sync_ignore_text_total)
    set(_lint_sync_line_text "${_lint_sync_ignore_text_${_lint_k}}")
    set(_lint_sync_line_number "${_lint_sync_ignore_text_line_${_lint_k}}")

    if(_lint_sync_line_text STREQUAL "```")
        if(_lint_check4_in_fence)
            set(_lint_check4_in_fence 0)
        else()
            set(_lint_check4_in_fence 1)
        endif()
    elseif(_lint_check4_in_fence)
        string(LENGTH "${_lint_sync_line_text}" _lint_pattern_len)
        if(_lint_pattern_len EQUAL 0)
            list(APPEND _lint_check4_findings "${_lint_identity_doc_source}:${_lint_sync_line_number}: empty Sync Ignore pattern")
        else()
            string(FIND "${_lint_sync_line_text}" "/" _lint_slash_pos)
            string(FIND "${_lint_sync_line_text}" "~" _lint_home_pos)
            if(_lint_slash_pos EQUAL 0)
                list(APPEND _lint_check4_findings "${_lint_identity_doc_source}:${_lint_sync_line_number}: Sync Ignore pattern '${_lint_sync_line_text}' must be relative (starts with '/')")
            elseif(_lint_home_pos EQUAL 0)
                list(APPEND _lint_check4_findings "${_lint_identity_doc_source}:${_lint_sync_line_number}: Sync Ignore pattern '${_lint_sync_line_text}' must be relative (starts with '~')")
            endif()
        endif()
    endif()
    math(EXPR _lint_k "${_lint_k}+1")
endwhile()

if(_lint_check4_findings)
    string(JOIN "\n" _lint_check4_message ${_lint_check4_findings})
    message(FATAL_ERROR "echo: lint: CHECK 4 failed:\n${_lint_check4_message}")
endif()

message(STATUS "✓ CHECK 4: Sync Ignore patterns relative")

# CHECK 5 — namespaceShort alias ban in kernel scope

set(_lint_check5_findings "")
set(_lint_word_chars "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")

if(DEFINED _lint_identity_namespaceShort)
    set(_lint_check5_needle "${_lint_identity_namespaceShort}::")
    string(LENGTH "${_lint_check5_needle}" _lint_check5_needle_len)

    set(_lint_k 0)
    while(_lint_k LESS _lint_modules_row_total)
        if(_lint_modules_row_${_lint_k}_role STREQUAL "data")
            echo_table_require(_lint_modules_row_${_lint_k} "module" _lint_check5_module_name)
            echo_table_require(_lint_modules_row_${_lint_k} "class" _lint_check5_module_class)

            if(_lint_check5_module_class STREQUAL "kernel")
                file(GLOB_RECURSE _lint_check5_files "${_lint_resolved_root}/${_lint_check5_module_name}/*")

                foreach(_lint_check5_file ${_lint_check5_files})
                    if(NOT IS_DIRECTORY "${_lint_check5_file}")
                        _verify_detect_binary("${_lint_check5_file}" _lint_check5_is_binary _lint_check5_content)

                        if(NOT _lint_check5_is_binary)
                            string(REPLACE "\r\n" "\n" _lint_check5_content "${_lint_check5_content}")
                            _echo_split_lines("${_lint_check5_content}" _lint_check5_line _lint_check5_line_total)

                            set(_lint_check5_line_i 0)
                            while(_lint_check5_line_i LESS _lint_check5_line_total)
                                set(_lint_check5_line_content "${_lint_check5_line_${_lint_check5_line_i}}")
                                math(EXPR _lint_check5_line_number "${_lint_check5_line_i}+1")

                                set(_lint_check5_search_start 0)
                                set(_lint_check5_scanning 1)
                                while(_lint_check5_scanning)
                                    string(SUBSTRING "${_lint_check5_line_content}" ${_lint_check5_search_start} -1 _lint_check5_remainder)
                                    string(FIND "${_lint_check5_remainder}" "${_lint_check5_needle}" _lint_check5_hit_pos)

                                    if(_lint_check5_hit_pos EQUAL -1)
                                        set(_lint_check5_scanning 0)
                                    else()
                                        math(EXPR _lint_check5_absolute_pos "${_lint_check5_search_start}+${_lint_check5_hit_pos}")

                                        set(_lint_check5_boundary_ok 1)
                                        if(_lint_check5_absolute_pos GREATER 0)
                                            math(EXPR _lint_check5_prev_pos "${_lint_check5_absolute_pos}-1")
                                            string(SUBSTRING "${_lint_check5_line_content}" ${_lint_check5_prev_pos} 1 _lint_check5_prev_char)
                                            string(FIND "${_lint_word_chars}" "${_lint_check5_prev_char}" _lint_check5_prev_char_pos)
                                            if(NOT _lint_check5_prev_char_pos EQUAL -1)
                                                set(_lint_check5_boundary_ok 0)
                                            endif()
                                        endif()

                                        if(_lint_check5_boundary_ok)
                                            list(APPEND _lint_check5_findings "${_lint_check5_file}:${_lint_check5_line_number}")
                                        endif()

                                        math(EXPR _lint_check5_search_start "${_lint_check5_absolute_pos}+${_lint_check5_needle_len}")
                                    endif()
                                endwhile()

                                math(EXPR _lint_check5_line_i "${_lint_check5_line_i}+1")
                            endwhile()
                        endif()
                    endif()
                endforeach()
            endif()
        endif()
        math(EXPR _lint_k "${_lint_k}+1")
    endwhile()

    if(_lint_check5_findings)
        string(JOIN "\n" _lint_check5_message ${_lint_check5_findings})
        message(FATAL_ERROR "echo: lint: CHECK 5 failed:\n${_lint_check5_message}")
    endif()

    message(STATUS "✓ CHECK 5: namespaceShort alias ban in kernel scope clean")
else()
    message(STATUS "✓ CHECK 5: namespaceShort alias ban skipped (no namespaceShort declared)")
endif()

# CHECK 6 — register truth

set(_lint_check6_findings "")
set(_lint_check6_scanned_files "")
set(_lint_check6_namespace_needle "namespace ${_lint_identity_namespace}")
set(_lint_check6_namespace_hit 0)
set(_lint_check6_macroprefix_hit 0)

set(_lint_k 0)
while(_lint_k LESS _lint_modules_row_total)
    if(_lint_modules_row_${_lint_k}_role STREQUAL "data")
        echo_table_require(_lint_modules_row_${_lint_k} "module" _lint_check6_module_name)
        echo_table_require(_lint_modules_row_${_lint_k} "class" _lint_check6_module_class)
        set(_lint_check6_module_file "${_lint_modules_row_${_lint_k}_file}")
        set(_lint_check6_module_line "${_lint_modules_row_${_lint_k}_line}")

        if(_lint_check6_module_class STREQUAL "kernel")
            set(_lint_check6_topmost_header "${_lint_resolved_root}/${_lint_check6_module_name}/${_lint_check6_module_name}.h")

            if(NOT EXISTS "${_lint_check6_topmost_header}")
                list(APPEND _lint_check6_findings "${_lint_check6_module_file}:${_lint_check6_module_line}: kernel module '${_lint_check6_module_name}' has no topmost header ${_lint_check6_topmost_header}")
            endif()

            file(GLOB_RECURSE _lint_check6_module_headers "${_lint_resolved_root}/${_lint_check6_module_name}/*.h")
            foreach(_lint_check6_header ${_lint_check6_module_headers})
                list(APPEND _lint_check6_scanned_files "${_lint_check6_header}")

                _verify_detect_binary("${_lint_check6_header}" _lint_check6_is_binary _lint_check6_content)

                if(NOT _lint_check6_is_binary)
                    string(FIND "${_lint_check6_content}" "${_lint_check6_namespace_needle}" _lint_check6_namespace_pos)
                    if(NOT _lint_check6_namespace_pos EQUAL -1)
                        set(_lint_check6_namespace_hit 1)
                    endif()

                    string(FIND "${_lint_check6_content}" "${_lint_identity_macroPrefix}" _lint_check6_macroprefix_pos)
                    if(NOT _lint_check6_macroprefix_pos EQUAL -1)
                        set(_lint_check6_macroprefix_hit 1)
                    endif()
                endif()
            endforeach()
        endif()
    endif()
    math(EXPR _lint_k "${_lint_k}+1")
endwhile()

if(_lint_check6_findings)
    string(JOIN "\n" _lint_check6_message ${_lint_check6_findings})
    message(FATAL_ERROR "echo: lint: CHECK 6 failed:\n${_lint_check6_message}")
endif()

string(JOIN ", " _lint_check6_scanned_joined ${_lint_check6_scanned_files})

if(NOT _lint_check6_namespace_hit)
    message(FATAL_ERROR "echo: lint: CHECK 6 failed: declared namespace '${_lint_identity_namespace}' found in no kernel module header\nfiles scanned: ${_lint_check6_scanned_joined}")
endif()

if(NOT _lint_check6_macroprefix_hit)
    message(FATAL_ERROR "echo: lint: CHECK 6 failed: declared macroPrefix '${_lint_identity_macroPrefix}' found in no kernel module header\nfiles scanned: ${_lint_check6_scanned_joined}")
endif()

message(STATUS "✓ CHECK 6: register truth")

# CHECK 7 — provision hooks present

set(_lint_check7_findings "")
set(_lint_check7_section_present 0)

set(_lint_k 0)
while(_lint_k LESS _lint_identity_doc_total)
    if(_lint_identity_doc_type_${_lint_k} STREQUAL "heading" AND _lint_identity_doc_heading_${_lint_k} STREQUAL "Provision Hooks")
        set(_lint_check7_section_present 1)
    endif()
    math(EXPR _lint_k "${_lint_k}+1")
endwhile()

if(_lint_check7_section_present)
    echo_table_section(_lint_identity_doc "Provision Hooks" _lint_provision_hooks)

    set(_lint_k 0)
    while(_lint_k LESS _lint_provision_hooks_row_total)
        if(_lint_provision_hooks_row_${_lint_k}_role STREQUAL "data")
            echo_table_require(_lint_provision_hooks_row_${_lint_k} "guard" _lint_check7_guard)
            echo_table_require(_lint_provision_hooks_row_${_lint_k} "file" _lint_check7_relative_file)
            set(_lint_check7_table_file "${_lint_provision_hooks_row_${_lint_k}_file}")
            set(_lint_check7_table_line "${_lint_provision_hooks_row_${_lint_k}_line}")

            set(_lint_check7_target_file "${_lint_resolved_root}/${_lint_check7_relative_file}")
            set(_lint_check7_needle "#if ${_lint_check7_guard}")

            if(NOT EXISTS "${_lint_check7_target_file}")
                list(APPEND _lint_check7_findings "${_lint_check7_table_file}:${_lint_check7_table_line}: provision hook removed: ${_lint_check7_guard} missing from ${_lint_check7_target_file} — required by rendered frameworks")
            else()
                file(READ "${_lint_check7_target_file}" _lint_check7_content)
                string(FIND "${_lint_check7_content}" "${_lint_check7_needle}" _lint_check7_hit_pos)
                if(_lint_check7_hit_pos EQUAL -1)
                    list(APPEND _lint_check7_findings "${_lint_check7_table_file}:${_lint_check7_table_line}: provision hook removed: ${_lint_check7_guard} missing from ${_lint_check7_target_file} — required by rendered frameworks")
                endif()
            endif()
        endif()
        math(EXPR _lint_k "${_lint_k}+1")
    endwhile()

    if(_lint_check7_findings)
        string(JOIN "\n" _lint_check7_message ${_lint_check7_findings})
        message(FATAL_ERROR "echo: lint: CHECK 7 failed:\n${_lint_check7_message}")
    endif()

    message(STATUS "✓ CHECK 7: provision hooks present")
else()
    message(STATUS "✓ CHECK 7: provision hooks skipped (no Provision Hooks section declared)")
endif()
