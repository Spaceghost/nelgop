#ifndef NELGOP_WIRE_H
#define NELGOP_WIRE_H
#include <stdbool.h>
#include <stdint.h>
/* Source is borrowed read-only. All output objects are disjoint from source
 * and each other. No modifications occur on failure. */
bool nelgop_wire_header(uint8_t *src, uintptr_t src_len,
                        uint32_t *width, uint32_t *height, uintptr_t *frame_len);
/* Valid disjoint byte spans required. The source must contain exactly one
 * frame. On failure the entire destination is unchanged. */
bool nelgop_wire_rgba(uint8_t *src, uintptr_t src_len,
                      uint8_t *dst, uintptr_t dst_capacity);
#endif
