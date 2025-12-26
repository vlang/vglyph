module text_render

import gg
import encoding.binary

pub struct CachedGlyph {
pub:
	image gg.Image
	left  int
	top   int
}

pub struct Renderer {
mut:
	ctx &gg.Context
	cache map[u64]CachedGlyph
}

pub fn new_renderer(ctx &gg.Context) &Renderer {
	return &Renderer{
		ctx: ctx
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
				r.ctx.draw_image(draw_x, draw_y, f32(cg.image.width), f32(cg.image.height), cg.image)
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
			image: gg.Image{ id: 0 } 
			left: 0
			top: 0
		}
	}

	// create BMP (Black text)
	bmp_data := create_bmp(bitmap.buffer, width, height)
	
	img := r.ctx.create_image_from_memory(bmp_data.data, bmp_data.len) or {
		println('Failed to create glyph image')
		return CachedGlyph{}
	}
	
	return CachedGlyph{
		image: img
		left: int(font.ft_face.glyph.bitmap_left)
		top: int(font.ft_face.glyph.bitmap_top)
	}
}

fn create_bmp(buffer &u8, w int, h int) []u8 {
	// 32-bit BMP
	header_size := 54
	data_size := w * h * 4
	file_size := header_size + data_size
	
	mut bmp := []u8{len: file_size}
	
	// Header letters
	bmp[0] = 0x42 // B
	bmp[1] = 0x4D // M
	binary.little_endian_put_u32(mut bmp[2..6], u32(file_size))
	binary.little_endian_put_u32(mut bmp[10..14], u32(header_size)) // offset
	
	// DIB Header
	binary.little_endian_put_u32(mut bmp[14..18], 40) // header size
	binary.little_endian_put_u32(mut bmp[18..22], u32(w))
	
	// Standard bottom-up BMP (positive height)
	binary.little_endian_put_u32(mut bmp[22..26], u32(h)) 
	
	binary.little_endian_put_u16(mut bmp[26..28], 1) // planes
	binary.little_endian_put_u16(mut bmp[28..30], 32) // bpp
	
	// Data
	mut ptr := header_size
	unsafe {
		// Buffer is Top-Down (FreeType). BMP is Bottom-Up.
		// We need to write the last row of buffer first? 
		// No, BMP stores bottom row first.
		// So row 0 of BMP data = row (h-1) of Buffer.
		
		for y in 0 .. h {
			// Source row (Top-down)
			src_y := h - 1 - y
			src_row_start := src_y * w
			
			for x in 0 .. w {
				val := buffer[src_row_start + x]
				
				// BGRA
				// Black text (0,0,0) with Alpha=val
				bmp[ptr] = 0
				bmp[ptr+1] = 0
				bmp[ptr+2] = 0
				bmp[ptr+3] = val
				ptr += 4
			}
		}
	}
	
	return bmp
}
