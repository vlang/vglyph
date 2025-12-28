module text_render

import gg

pub struct Bitmap {
pub:
	width    int
	height   int
	channels int
	data     []u8
}

pub struct Renderer {
mut:
	ctx   &gg.Context
	atlas GlyphAtlas
	cache map[u64]CachedGlyph
}

pub fn new_renderer(mut ctx gg.Context) &Renderer {
	mut atlas := new_glyph_atlas(mut ctx, 1024, 1024) // 1024x1024 default atlas
	return &Renderer{
		ctx:   ctx
		atlas: atlas
		cache: map[u64]CachedGlyph{}
	}
}

pub fn (mut r Renderer) draw_layout(layout Layout, x f32, y f32) {
	// If atlas has new glyphs, update GPU once
	if r.atlas.dirty {
		r.atlas.image.update_pixel_data(r.atlas.image.data)
		r.atlas.dirty = false
	}

	mut cx := x
	mut cy := y

	for item in layout.items {
		font_id := u64(voidptr(item.font.ft_face))

		for glyph in item.glyphs {
			key := font_id ^ (u64(glyph.index) << 32)

			// Load glyph into atlas if not cached
			if key !in r.cache {
				cg := r.load_glyph(item.font, glyph.index) or {
					// fallback blank glyph
					CachedGlyph{
						u0:   0
						v0:   0
						u1:   0
						v1:   0
						left: 0
						top:  0
					}
				}
				r.cache[key] = cg
			}

			cg := r.cache[key] or { continue }

			// Compute draw position
			draw_x := cx + f32(glyph.x_offset) + f32(cg.left)
			draw_y := cy - f32(glyph.y_offset) - f32(cg.top)

			glyph_w := f32((cg.u1 - cg.u0) * f32(r.atlas.width))
			glyph_h := f32((cg.v1 - cg.v0) * f32(r.atlas.height))

			// Destination and source rects
			dst := gg.Rect{
				x:      draw_x
				y:      draw_y
				width:  glyph_w
				height: glyph_h
			}
			src := gg.Rect{
				x:      cg.u0 * f32(r.atlas.width)
				y:      cg.v0 * f32(r.atlas.height)
				width:  (cg.u1 - cg.u0) * f32(r.atlas.width)
				height: (cg.v1 - cg.v0) * f32(r.atlas.height)
			}

			if cg.u0 != cg.u1 && cg.v0 != cg.v1 {
				r.ctx.draw_image_part(dst, src, &r.atlas.image)
			}

			// Advance cursor
			cx += f32(glyph.x_advance)
			cy -= f32(glyph.y_advance)
		}
	}
}

fn (mut r Renderer) load_glyph(font &Font, index u32) !CachedGlyph {
	flags := C.FT_LOAD_RENDER | C.FT_LOAD_COLOR

	if C.FT_Load_Glyph(font.ft_face, index, flags) != 0 {
		return error('FT_Load_Glyph failed')
	}

	bmp := font.ft_face.glyph.bitmap

	if bmp.buffer == 0 || bmp.width == 0 || bmp.rows == 0 {
		return CachedGlyph{} // space or empty glyph
	}

	bitmap := ft_bitmap_to_bitmap(&bmp)!
	return r.atlas.insert_bitmap(bitmap, int(font.ft_face.glyph.bitmap_left), int(font.ft_face.glyph.bitmap_top))
}

pub fn ft_bitmap_to_bitmap(bmp &C.FT_Bitmap) !Bitmap {
	if bmp.buffer == 0 || bmp.width == 0 || bmp.rows == 0 {
		return error('Empty bitmap')
	}

	mut width := int(bmp.width)
	mut height := int(bmp.rows)
	channels := 4

	mut data := []u8{len: width * height * channels, init: unsafe { bmp.buffer[index] }}

	match bmp.pixel_mode {
		u8(C.FT_PIXEL_MODE_GRAY) {
			for y in 0 .. height {
				row := unsafe {
					if bmp.pitch >= 0 {
						bmp.buffer + y * bmp.pitch
					} else {
						bmp.buffer + (height - 1 - y) * (-bmp.pitch)
					}
				}
				for x in 0 .. width {
					v := unsafe { row[x] }
					i := (y * width + x) * 4
					data[i + 0] = 255
					data[i + 1] = 255
					data[i + 2] = 255
					data[i + 3] = v
				}
			}
		}
		u8(C.FT_PIXEL_MODE_MONO) {
			for y in 0 .. height {
				row := unsafe {
					if bmp.pitch >= 0 {
						bmp.buffer + y * bmp.pitch
					} else {
						bmp.buffer + (height - 1 - y) * (-bmp.pitch)
					}
				}
				for x in 0 .. width {
					byte := unsafe { row[x >> 3] }
					bit := 7 - (x & 7)
					val := if ((byte >> bit) & 1) != 0 { u8(255) } else { u8(0) }

					i := (y * width + x) * 4
					data[i + 0] = val
					data[i + 1] = val
					data[i + 2] = val
					data[i + 3] = 255
				}
			}
		}
		u8(C.FT_PIXEL_MODE_BGRA) {
			for y in 0 .. height {
				row := unsafe { bmp.buffer + y * bmp.pitch }
				for x in 0 .. width {
					src := unsafe { row + x * 4 }
					i := (y * width + x) * 4
					data[i + 0] = unsafe { src[2] } // R
					data[i + 1] = unsafe { src[1] } // G
					data[i + 2] = unsafe { src[0] } // B
					data[i + 3] = unsafe { src[3] } // A
				}
			}
			// if bmp.pixel_mode == C.FT_PIXEL_MODE_BGRA {
			// 	scale := f32(30) / f32(height)
			// 	new_w := int(f32(width) * scale)
			// 	new_h := int(f32(height) * scale)
			//
			// 	data = scale_bitmap_nn(data, width, height, new_w, new_h)
			// 	width = new_w
			// 	height = new_h
			// }
		}
		else {
			return error('Unsupported FT pixel mode: ${bmp.pixel_mode}')
		}
	}

	return Bitmap{
		width:    width
		height:   height
		channels: channels
		data:     data
	}
}

// Scale RGBA bitmap using nearest-neighbor
pub fn scale_bitmap_nn(src []u8, src_w int, src_h int, dst_w int, dst_h int) []u8 {
	mut dst := []u8{len: dst_w * dst_h * 4, init: 0}
	for y in 0 .. dst_h {
		for x in 0 .. dst_w {
			src_x := int(f32(x) * f32(src_w) / f32(dst_w))
			src_y := int(f32(y) * f32(src_h) / f32(dst_h))
			src_idx := (src_y * src_w + src_x) * 4
			dst_idx := (y * dst_w + x) * 4
			dst[dst_idx + 0] = src[src_idx + 0]
			dst[dst_idx + 1] = src[src_idx + 1]
			dst[dst_idx + 2] = src[src_idx + 2]
			dst[dst_idx + 3] = src[src_idx + 3]
		}
	}
	return dst
}
