// -*- mode: c; tab-width: 2; indent-tabs-mode: nil; -*-
//--------------------------------------------------------------------------------------------------
// Copyright (c) 2019 Marcus Geelnard
//
// This software is provided 'as-is', without any express or implied warranty. In no event will the
// authors be held liable for any damages arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose, including commercial
// applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not claim that you wrote
//     the original software. If you use this software in a product, an acknowledgment in the
//     product documentation would be appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be misrepresented as
//     being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//--------------------------------------------------------------------------------------------------

#ifndef MC1_MEM_FILL_H_
#define MC1_MEM_FILL_H_

#include <mc1/types.h>

/// @brief Fill memory with a value.
///
/// Fill the given block of memory using the unsigned char conversion of the value argument.
/// @param ptr Target memory pointer (start of buffer).
/// @param value The value (0-255) to fill with.
/// @param num Number of bytes to fill.
/// @returns the @c ptr pointer.
void* mem_fill(void* ptr, int value, size_t num);

#endif  // MC1_MEM_FILL_H_
