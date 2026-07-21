include("${CMAKE_CURRENT_LIST_DIR}/verify.cmake")

# ============================================================================
# Direct-invocation gate — same technique as verify.cmake's own gate, keyed
# to this file's name so the include() above never runs verify.cmake's
# run block here.
# ============================================================================

get_filename_component(_diff_self_name "${CMAKE_CURRENT_LIST_FILE}" NAME)
set(_diff_self_index -1)
set(_diff_i 0)
while(_diff_i LESS CMAKE_ARGC)
    get_filename_component(_diff_argv_name "${CMAKE_ARGV${_diff_i}}" NAME)
    if(_diff_argv_name STREQUAL _diff_self_name)
        set(_diff_self_index ${_diff_i})
    endif()
    math(EXPR _diff_i "${_diff_i}+1")
endwhile()

if(_diff_self_index GREATER -1)
    include("${CMAKE_CURRENT_LIST_DIR}/echo.cmake")

    set(_diff_user_arg_count 0)
    math(EXPR _diff_user_arg_start "${_diff_self_index}+1")
    set(_diff_i ${_diff_user_arg_start})
    while(_diff_i LESS CMAKE_ARGC)
        if(_diff_user_arg_count EQUAL 0)
            set(_diff_name_a "${CMAKE_ARGV${_diff_i}}")
        elseif(_diff_user_arg_count EQUAL 1)
            set(_diff_name_b "${CMAKE_ARGV${_diff_i}}")
        endif()
        math(EXPR _diff_user_arg_count "${_diff_user_arg_count}+1")
        math(EXPR _diff_i "${_diff_i}+1")
    endwhile()

    if(NOT _diff_user_arg_count EQUAL 2)
        message(FATAL_ERROR "usage: cmake -P diff.cmake <frameworkNameOrPath-A> <frameworkNameOrPath-B>\nA name containing '/' is treated as a literal root path instead of a frameworks.md registry lookup.")
    endif()

    _verify_run_comparison("${_diff_name_a}" "${_diff_name_b}")

    execute_process(
        COMMAND git diff --no-index "${_verify_export_a_dir}" "${_verify_export_b_dir}"
    )
endif()
