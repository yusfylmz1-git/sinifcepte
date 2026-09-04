#include <cstdint>
#include <cstddef>
#include <cstring>
#include <chrono>
#include <thread>
#include <cstdlib>

// Compatibility implementations for MSVC STL vectorized and runtime functions
// when linking against prebuilt libraries (e.g. Firebase C++ SDK) on Visual Studio 2019/2022.

extern "C" {

const void* __cdecl __std_find_trivial_1(const void* _First, const void* _Last, uint8_t _Val) {
    const auto* p = static_cast<const uint8_t*>(_First);
    const auto* end = static_cast<const uint8_t*>(_Last);
    while (p != end) {
        if (*p == _Val) return p;
        ++p;
    }
    return end;
}

const void* __cdecl __std_find_trivial_2(const void* _First, const void* _Last, uint16_t _Val) {
    const auto* p = static_cast<const uint16_t*>(_First);
    const auto* end = static_cast<const uint16_t*>(_Last);
    while (p != end) {
        if (*p == _Val) return p;
        ++p;
    }
    return end;
}

const void* __cdecl __std_find_trivial_4(const void* _First, const void* _Last, uint32_t _Val) {
    const auto* p = static_cast<const uint32_t*>(_First);
    const auto* end = static_cast<const uint32_t*>(_Last);
    while (p != end) {
        if (*p == _Val) return p;
        ++p;
    }
    return end;
}

const void* __cdecl __std_find_trivial_8(const void* _First, const void* _Last, uint64_t _Val) {
    const auto* p = static_cast<const uint64_t*>(_First);
    const auto* end = static_cast<const uint64_t*>(_Last);
    while (p != end) {
        if (*p == _Val) return p;
        ++p;
    }
    return end;
}

const void* __cdecl __std_find_last_trivial_1(const void* _First, const void* _Last, uint8_t _Val) {
    const auto* begin = static_cast<const uint8_t*>(_First);
    const auto* p = static_cast<const uint8_t*>(_Last);
    while (p != begin) {
        --p;
        if (*p == _Val) return p;
    }
    return static_cast<const uint8_t*>(_Last);
}

const void* __cdecl __std_find_last_trivial_2(const void* _First, const void* _Last, uint16_t _Val) {
    const auto* begin = static_cast<const uint16_t*>(_First);
    const auto* p = static_cast<const uint16_t*>(_Last);
    while (p != begin) {
        --p;
        if (*p == _Val) return p;
    }
    return static_cast<const uint16_t*>(_Last);
}

const void* __cdecl __std_find_last_trivial_4(const void* _First, const void* _Last, uint32_t _Val) {
    const auto* begin = static_cast<const uint32_t*>(_First);
    const auto* p = static_cast<const uint32_t*>(_Last);
    while (p != begin) {
        --p;
        if (*p == _Val) return p;
    }
    return static_cast<const uint32_t*>(_Last);
}

const void* __cdecl __std_find_last_trivial_8(const void* _First, const void* _Last, uint64_t _Val) {
    const auto* begin = static_cast<const uint64_t*>(_First);
    const auto* p = static_cast<const uint64_t*>(_Last);
    while (p != begin) {
        --p;
        if (*p == _Val) return p;
    }
    return static_cast<const uint64_t*>(_Last);
}

const char* __cdecl __std_search_1(const char* _First1, const char* _Last1, const char* _First2, size_t _Count2) {
    if (_Count2 == 0) return _First1;
    const size_t count1 = static_cast<size_t>(_Last1 - _First1);
    if (count1 < _Count2) return _Last1;
    const char* end = _Last1 - _Count2 + 1;
    for (const char* p = _First1; p < end; ++p) {
        if (std::memcmp(p, _First2, _Count2) == 0) {
            return p;
        }
    }
    return _Last1;
}

const char* __cdecl __std_find_end_1(const char* _First1, const char* _Last1, const char* _First2, size_t _Count2) {
    if (_Count2 == 0) return _Last1;
    const size_t count1 = static_cast<size_t>(_Last1 - _First1);
    if (count1 < _Count2) return _Last1;
    const char* p = _Last1 - _Count2;
    for (;;) {
        if (std::memcmp(p, _First2, _Count2) == 0) {
            return p;
        }
        if (p == _First1) break;
        --p;
    }
    return _Last1;
}

const char* __cdecl __std_find_first_of_trivial_1(const char* _First1, const char* _Last1, const char* _First2, const char* _Last2) {
    for (const char* p1 = _First1; p1 != _Last1; ++p1) {
        for (const char* p2 = _First2; p2 != _Last2; ++p2) {
            if (*p1 == *p2) return p1;
        }
    }
    return _Last1;
}

size_t __cdecl __std_find_last_of_trivial_pos_1(const char* _First1, size_t _Count1, const char* _First2, size_t _Count2) {
    if (_Count1 == 0 || _Count2 == 0) return static_cast<size_t>(-1);
    for (size_t i = _Count1; i > 0; --i) {
        const char c = _First1[i - 1];
        for (size_t j = 0; j < _Count2; ++j) {
            if (c == _First2[j]) return i - 1;
        }
    }
    return static_cast<size_t>(-1);
}

void* __cdecl __std_remove_8(void* _First, void* _Last, uint64_t _Val) {
    auto* first = static_cast<uint64_t*>(_First);
    auto* last = static_cast<uint64_t*>(_Last);
    auto* result = first;
    for (; first != last; ++first) {
        if (*first != _Val) {
            if (result != first) {
                *result = *first;
            }
            ++result;
        }
    }
    return result;
}

const int64_t* __cdecl __std_min_element_8(const int64_t* _First, const int64_t* _Last) {
    if (_First == _Last) return _Last;
    const int64_t* min_elem = _First;
    for (const int64_t* p = _First + 1; p < _Last; ++p) {
        if (*p < *min_elem) {
            min_elem = p;
        }
    }
    return min_elem;
}

int64_t __cdecl __std_min_8i(const int64_t* _First, const int64_t* _Last) {
    if (_First == _Last) return 0;
    int64_t min_val = *_First;
    for (const int64_t* p = _First + 1; p < _Last; ++p) {
        if (*p < min_val) {
            min_val = *p;
        }
    }
    return min_val;
}

void __cdecl _Thrd_sleep_for(const void* _Rel_time) {
    if (_Rel_time) {
        const auto* ptr = static_cast<const int64_t*>(_Rel_time);
        if (*ptr > 0) {
            std::this_thread::sleep_for(std::chrono::nanoseconds(*ptr));
        }
    }
}

int __cdecl _Cnd_timedwait_for_unchecked(void* cond, void* mtx, unsigned int target_ms) {
    std::this_thread::sleep_for(std::chrono::milliseconds(target_ms));
    return 0;
}

void __cdecl __std_init_once_link_alternate_names_and_abort() {
    std::abort();
}

void* __cdecl compat_bad_cast_ctor(void* this_ptr, const char* msg) {
    return this_ptr;
}

void __cdecl compat_bad_cast_doraise(const void* this_ptr) {
    std::abort();
}

void* compat_bad_cast_ctor_ptr = (void*)&compat_bad_cast_ctor;

}

#if defined(_MSC_VER)
#pragma comment(linker, "/alternatename:__imp_??0bad_cast@std@@QEAA@PEBD@Z=compat_bad_cast_ctor_ptr")
#pragma comment(linker, "/alternatename:?_Doraise@bad_cast@std@@MEBAXXZ=compat_bad_cast_doraise")
#endif
