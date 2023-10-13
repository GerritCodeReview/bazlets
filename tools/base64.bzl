# Copyright (C) 2023 Serge 'q3k' Bazanski
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

_BASE64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'


def _int_to_bin(n, width=8):
    """
    Convert an integer number into its binary (big endian) representation at a
    given width.

    Needed as Starlark doesn't have `bin`.
    """
    res = ""
    for i in range(width):
        bit = (n >> i) & 1
        if bit == 1:
            res = "1" + res
        else:
            res = "0" + res
    return res


def hex_to_b64(data):
    """
    Convert a hex-encoded string to a base64-encoded string.
    """

    # We operate on lowercase hexstrings internally.
    data = data.lower()

    if (len(data) % 2) != 0:
        fail("invalid hex string (not an even number of characters")

    # Hex-encoded, so length of string == number of nibbles == 2*number of
    # bytes.
    nbytes = len(data) // 2

    # How many padding nulls do we need to reach a multiple of 3 bytes?
    npad = 0
    if nbytes % 3 != 0:
        npad = 3 - (nbytes % 3)
    # Extend string with synthetic nulls. We'll remove them later.
    data = data + "00" * npad

    # Convert into bitstring (string of '0' and '1' chars).
    bitstring = ""
    for i in range(len(data)//2):
        bitstring += _int_to_bin(int(data[i*2:i*2+2], 16))

    # Group by 24 bits and convert to B64 alphabet.
    res = ""
    for i in range(len(bitstring)//6):
        chunk = bitstring[i*6:i*6+6]
        chunk = int(chunk, 2)
        res += _BASE64[chunk]
    # Strip back any padding and replace with padding markers.
    if npad != 0:
        res = res[:-npad]
        res += '=' * npad
    return res
