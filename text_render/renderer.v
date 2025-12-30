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

pub fn (mut renderer Renderer) draw_layout(layout Layout, x f32, y f32) {
	// If atlas has new glyphs, update GPU once (sokol restriction)
	if renderer.atlas.dirty {
		renderer.atlas.image.update_pixel_data(renderer.atlas.image.data)
		renderer.atlas.dirty = false
	}

	mut cx := x
	mut cy := y + renderer.max_visual_height(layout)

	for item in layout.items {
		font_id := u64(voidptr(item.font.ft_face))

		for glyph in item.glyphs {
			key := font_id ^ (u64(glyph.index) << 32)

			cg := renderer.cache[key] or {
				cached_glyph := renderer.load_glyph(item.font, glyph.index) or {
					CachedGlyph{} // fallback blank glyph
				}
				renderer.cache[key] = cached_glyph
				cached_glyph
			}

			// Compute draw position
			draw_x := cx + f32(glyph.x_offset) + f32(cg.left)
			draw_y := cy - f32(glyph.y_offset) - f32(cg.top)

			glyph_w := f32((cg.u1 - cg.u0) * f32(renderer.atlas.width))
			glyph_h := f32((cg.v1 - cg.v0) * f32(renderer.atlas.height))

			// Draw image from glyph atlas
			if cg.u0 != cg.u1 && cg.v0 != cg.v1 {
				dst := gg.Rect{
					x:      draw_x
					y:      draw_y
					width:  glyph_w
					height: glyph_h
				}
				src := gg.Rect{
					x:      cg.u0 * f32(renderer.atlas.width)
					y:      cg.v0 * f32(renderer.atlas.height)
					width:  (cg.u1 - cg.u0) * f32(renderer.atlas.width)
					height: (cg.v1 - cg.v0) * f32(renderer.atlas.height)
				}
				renderer.ctx.draw_image_part(dst, src, &renderer.atlas.image)
			}

			// Advance cursor
			cx += f32(glyph.x_advance)
			cy -= f32(glyph.y_advance)
		}

		// r.ctx.draw_image(10, 100, 1024, 1024, r.atlas.image)
	}
}

fn (mut renderer Renderer) max_visual_height(layout Layout) f32 {
	mut top := f32(0)
	mut bottom := f32(0)

	for item in layout.items {
		font_id := u64(voidptr(item.font.ft_face))

		for glyph in item.glyphs {
			key := font_id ^ (u64(glyph.index) << 32)

			cg := renderer.cache[key] or {
				cached_glyph := renderer.load_glyph(item.font, glyph.index) or {
					CachedGlyph{} // fallback blank glyph
				}
				renderer.cache[key] = cached_glyph
				cached_glyph
			}

			// FreeType convention:
			//  - cg.top is bitmap_top
			//  - glyph.y_offset is HarfBuzz vertical offset (pixels)
			glyph_top := f32(cg.top - glyph.y_offset)
			glyph_height := (cg.v1 - cg.v0) * f32(renderer.atlas.height)
			glyph_bottom := glyph_top - glyph_height

			if glyph_top > top {
				top = glyph_top
			}
			if glyph_bottom < bottom {
				bottom = glyph_bottom
			}
		}
	}
	return top - bottom
}
