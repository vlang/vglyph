module vglyph

import gg
import gg.render

fn test_glyph_and_decoration_quads_record_into_the_gg_context() {
	r := render.new_context(max_vertices: 32, max_commands: 8)
	other := render.new_context(max_vertices: 32, max_commands: 8)
	defer { r.destroy() }
	defer { other.destroy() }
	ctx := &gg.Context{ r: r }
	renderer := Renderer{
		ctx:   ctx
		atlas: GlyphAtlas{ ctx: ctx }
	}
	r.begin_quads()
	renderer.emit_placed_quad(CachedGlyph{ width: 4, height: 4 },
		GlyphPlacement{ x: 4, y: 4 }, AtlasPage{ width: 16, height: 16 }, gg.white,
		4, 0, false, 4)
	emit_decoration_quad(r, affine_identity(), 0, 0, 0, 0, 4, 1, gg.white,
		false, unsafe { nil }, 4, 1, 0, 0)
	r.end()
	assert r.num_vertices() == 12
	assert other.num_vertices() == 0
	assert r.error() == .no_error
}

fn test_atlas_copy_uses_byte_counts_and_preserves_adjacent_pixels() {
	mut page := AtlasPage{
		width:        4
		height:       3
		staging_back: []u8{len: 4 * 3 * 4}
	}
	bmp := Bitmap{
		width:    2
		height:   2
		channels: 4
		data:     []u8{len: 16, init: u8(index + 1)}
	}
	copy_bitmap_to_page(mut page, bmp, 1, 1)!
	assert page.staging_back[20..28] == bmp.data[..8]
	assert page.staging_back[36..44] == bmp.data[8..]
	assert page.staging_back[16..20] == [u8(0), 0, 0, 0]
	assert page.staging_back[28..32] == [u8(0), 0, 0, 0]
}
