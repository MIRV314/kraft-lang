local function prelude_f_1(prelude_v_1)
    do local __ret_1 = krt.list_join(prelude_v_1, ""); return __ret_1 end
end
local function prelude_f_2(prelude_v_2, prelude_v_3)
    if krt.truthy_strict((prelude_v_2 == "")) then
        do local __ret_2 = prelude_v_3; return __ret_2 end
    end
    if krt.truthy_strict((prelude_v_3 == "")) then
        do local __ret_3 = prelude_v_2; return __ret_3 end
    end
    if krt.truthy_strict(krt.str_suff(prelude_v_2, "/")) then
        do local __ret_4 = prelude_f_1(krt.list({prelude_v_2, prelude_v_3})); return __ret_4 end
    end
    do local __ret_5 = prelude_f_1(krt.list({prelude_v_2, "/", prelude_v_3})); return __ret_5 end
end
local function prelude_f_3()
    do local __ret_6 = krt.time_ms(); return __ret_6 end
end
local function prelude_f_4()
    local prelude_v_4, prelude_v_5, prelude_v_6, prelude_v_7, prelude_v_8 = krt.NONE, krt.NONE, krt.NONE, krt.NONE, krt.NONE
    prelude_v_4 = krt.dict()
    prelude_v_5 = krt.args()
    prelude_v_6 = (1)
    while krt.truthy_strict((krt.as_flint(prelude_v_6) < krt.len(prelude_v_5))) do
        prelude_v_7 = krt.as_str(krt.list_index(krt.as_list(prelude_v_5), krt.as_flint(prelude_v_6)))
        if krt.truthy_strict(krt.str_preff(krt.as_str(prelude_v_7), "--")) then
            prelude_v_8 = krt.str_find(krt.as_str(prelude_v_7), "=")
            if krt.truthy_strict((prelude_v_8 == krt.NONE or prelude_v_8 == nil)) then
                krt.dict_add(krt.as_dict(prelude_v_4), krt.str_slice(krt.as_str(prelude_v_7), (2), krt.len(prelude_v_7)), "TRUE")
            else
                krt.dict_add(krt.as_dict(prelude_v_4), krt.str_slice(krt.as_str(prelude_v_7), (2), krt.as_flint(prelude_v_8)), krt.str_slice(krt.as_str(prelude_v_7), (krt.as_flint(prelude_v_8) + (1)), krt.len(prelude_v_7)))
            end
        else
            krt.dict_add(krt.as_dict(prelude_v_4), krt.tostr((krt.as_flint(prelude_v_6) - (1))), prelude_v_7)
        end
        prelude_v_6 = (krt.as_flint(prelude_v_6) + (1))
        ::__continue_1::
    end
    ::__break_1::
    do local __ret_7 = prelude_v_4; return __ret_7 end
end
local function prelude_f_5(prelude_v_9)
    local prelude_v_10, prelude_v_11, prelude_v_13 = krt.NONE, krt.NONE, krt.NONE
    prelude_v_10 = krt.list({})
    prelude_v_11 = krt.str_part(prelude_v_9, "\n")
    do
        local __coll_2 = krt.as_list(prelude_v_11)
        local __i_2 = 0
        while __i_2 < #__coll_2 do
            local prelude_v_12 = __coll_2[__i_2 + 1]
            prelude_v_13 = krt.as_str(prelude_v_12)
            if krt.truthy_strict((krt.str_trim(krt.as_str(prelude_v_13)) == "")) then
                goto __continue_2
            end
            krt.list_add(krt.as_list(prelude_v_10), krt.str_part(krt.as_str(prelude_v_13), ","))
            ::__continue_2::
            __i_2 = __i_2 + 1
        end
    end
    ::__break_2::
    do local __ret_8 = prelude_v_10; return __ret_8 end
end
local function prelude_f_6(prelude_v_14)
    local prelude_v_15, prelude_v_16, prelude_v_17, prelude_v_18, prelude_v_20, prelude_v_21, prelude_v_22, prelude_v_23 = krt.NONE, krt.NONE, krt.NONE, krt.NONE, krt.NONE, krt.NONE, krt.NONE, krt.NONE
    prelude_v_15 = krt.dict()
    prelude_v_16 = krt.str_trim(prelude_v_14)
    krt.do_assert_strict((krt.truthy_strict(krt.str_preff(krt.as_str(prelude_v_16), "{")) and krt.truthy_strict(krt.str_suff(krt.as_str(prelude_v_16), "}"))), "json object expected")
    prelude_v_17 = krt.str_slice(krt.as_str(prelude_v_16), (1), (krt.len(prelude_v_16) - (1)))
    if krt.truthy_strict((krt.str_trim(krt.as_str(prelude_v_17)) == "")) then
        do local __ret_9 = prelude_v_15; return __ret_9 end
    end
    prelude_v_18 = krt.str_part(krt.as_str(prelude_v_17), ",")
    do
        local __coll_3 = krt.as_list(prelude_v_18)
        local __i_3 = 0
        while __i_3 < #__coll_3 do
            local prelude_v_19 = __coll_3[__i_3 + 1]
            prelude_v_20 = krt.as_str(prelude_v_19)
            prelude_v_20 = krt.str_trim(krt.as_str(prelude_v_20))
            prelude_v_21 = krt.str_find(krt.as_str(prelude_v_20), ":")
            if krt.truthy_strict((prelude_v_21 == krt.NONE or prelude_v_21 == nil)) then
                goto __continue_3
            end
            prelude_v_22 = krt.str_trim(krt.str_slice(krt.as_str(prelude_v_20), nil, krt.as_flint(prelude_v_21)))
            if krt.truthy_strict((krt.truthy_strict(krt.str_preff(krt.as_str(prelude_v_22), "\"")) and krt.truthy_strict(krt.str_suff(krt.as_str(prelude_v_22), "\"")))) then
                prelude_v_22 = krt.str_slice(krt.as_str(prelude_v_22), (1), (krt.len(prelude_v_22) - (1)))
            end
            prelude_v_23 = krt.str_trim(krt.str_slice(krt.as_str(prelude_v_20), (krt.as_flint(prelude_v_21) + (1)), krt.len(prelude_v_20)))
            if krt.truthy_strict((prelude_v_23 == "TRUE")) then
                krt.dict_add(krt.as_dict(prelude_v_15), krt.as_str(prelude_v_22), true)
            elseif krt.truthy_strict((prelude_v_23 == "FALSE")) then
                krt.dict_add(krt.as_dict(prelude_v_15), krt.as_str(prelude_v_22), false)
            elseif krt.truthy_strict((prelude_v_23 == "NONE")) then
                krt.dict_add(krt.as_dict(prelude_v_15), krt.as_str(prelude_v_22), krt.NONE)
            elseif krt.truthy_strict((krt.truthy_strict(krt.str_preff(krt.as_str(prelude_v_23), "\"")) and krt.truthy_strict(krt.str_suff(krt.as_str(prelude_v_23), "\"")))) then
                krt.dict_add(krt.as_dict(prelude_v_15), krt.as_str(prelude_v_22), krt.str_slice(krt.as_str(prelude_v_23), (1), (krt.len(prelude_v_23) - (1))))
            else
                krt.dict_add(krt.as_dict(prelude_v_15), krt.as_str(prelude_v_22), krt.to_flint(prelude_v_23))
            end
            ::__continue_3::
            __i_3 = __i_3 + 1
        end
    end
    ::__break_3::
    do local __ret_10 = prelude_v_15; return __ret_10 end
end
