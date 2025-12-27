module text_render

import gg

pub struct CachedGlyph {
pub:
	image gg.Image
	left  int
	top   int
}

pub struct Renderer {
mut:
	ctx   &gg.Context
	cache map[u64]CachedGlyph
}

pub fn new_renderer(ctx &gg.Context) &Renderer {
	return &Renderer{
		ctx:   ctx
		cache: map[u64]CachedGlyph{}
	}
}

pub fn (mut r Renderer) draw_layout(layout Layout, x f32, y f32) {
	mut cx := x
	mut cy := y

	for item in layout.items {
		font_id := u64(voidptr(item.font.ft_face))

		for glyph in item.glyphs {
			key := font_id ^ (u64(glyph.index) << 32)

			if key !in r.cache {
				cg := r.load_glyph(item.font, glyph.index)
				r.cache[key] = cg
			}

			cg := r.cache[key] or { CachedGlyph{} }

			// Position
			draw_x := cx + f32(glyph.x_offset) + f32(cg.left)
			draw_y := cy - f32(glyph.y_offset) - f32(cg.top)

			if cg.image.id != 0 {
				r.ctx.draw_image(draw_x, draw_y, f32(cg.image.width), f32(cg.image.height),
					cg.image)
			}

			cx += f32(glyph.x_advance)
			cy -= f32(glyph.y_advance)
		}
	}
}

fn (mut r Renderer) load_glyph(font &Font, index u32) CachedGlyph {
	if C.FT_Load_Glyph(font.ft_face, index, 0) != 0 {
		return CachedGlyph{}
	}
	C.FT_Render_Glyph(font.ft_face.glyph, C.ft_render_mode_normal)

	bitmap := font.ft_face.glyph.bitmap
	width := int(bitmap.width)
	height := int(bitmap.rows)

	if width == 0 || height == 0 {
		return CachedGlyph{
			image: gg.Image{
				id: 0
			}
			left:  0
			top:   0
		}
	}

	ft_bmp := ft_bitmap_to_bitmap(&bitmap) or { panic('ouch') }
	img := create_image_from_bitmap(mut r.ctx, &ft_bmp)

	return CachedGlyph{
		image: img
		left:  int(font.ft_face.glyph.bitmap_left)
		top:   int(font.ft_face.glyph.bitmap_top)
	}
}

fn create_image_from_bitmap(mut ctx gg.Context, bitmap &Bitmap) gg.Image {
	mut img := gg.Image{
		width:       bitmap.width
		height:      bitmap.height
		nr_channels: bitmap.channels
		data:        bitmap.data.data
	}

	img.init_sokol_image()
	img.id = ctx.cache_image(img)
	return img
}

// Convert a FreeType FT_Bitmap to a V image.Image
// Result container
pub struct Bitmap {
pub:
	width    int
	height   int
	channels int
	data     []u8
}

// Convert FreeType FT_Bitmap → RGBA bitmap
pub fn ft_bitmap_to_bitmap(bmp &C.FT_Bitmap) !Bitmap {
	if bmp.buffer == 0 {
		return error('FT_Bitmap buffer is null')
	}

	width := int(bmp.width)
	height := int(bmp.rows)
	channels := 4

	mut data := []u8{len: width * height * channels, init: 0}

	match bmp.pixel_mode {
		u8(C.FT_PIXEL_MODE_GRAY) {
			for y in 0 .. height {
				row := if bmp.pitch >= 0 {
					unsafe { bmp.buffer + y * bmp.pitch }
				} else {
					unsafe { bmp.buffer + (height - 1 - y) * (-bmp.pitch) }
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
				row := if bmp.pitch >= 0 {
					unsafe { bmp.buffer + y * bmp.pitch }
				} else {
					unsafe { bmp.buffer + (height - 1 - y) * (-bmp.pitch) }
				}
				for x in 0 .. width {
					byte := unsafe { row[x >> 3] }
					bit := 7 - (x & 7)
					on := (byte >> bit) & 1
					val := if on == 1 { u8(255) } else { u8(0) }

					i := (y * width + x) * 4
					data[i + 0] = val
					data[i + 1] = val
					data[i + 2] = val
					data[i + 3] = 255
				}
			}
		}
		else {
			return error('Unsupported FT_Bitmap pixel mode: ${bmp.pixel_mode}')
		}
	}

	return Bitmap{
		width:    width
		height:   height
		channels: channels
		data:     data
	}
}
