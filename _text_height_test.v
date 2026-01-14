module vglyph

import gg as _

// Test text_height caching optimization
// This ensures that text_height returns correct Ink dimensions even if the text has not been rendered.
fn test_text_height_no_draw() {
	mut ctx := new_context(1.0)!
	defer { ctx.free() }

	cfg := TextConfig{
		style: TextStyle{
			font_name: 'Sans 30'
		}
		block: BlockStyle{
			width: -1
			align: .left
		}
	}

	text := 'Hello'
	layout := ctx.layout_text(text, cfg)!

	// Previously (before optimization), we might have needed the renderer to load glyphs
	// to get the visual height via max_visual_height iteration over items.
	// Now, layout_text should have populated visual_height directly from Pango.

	assert layout.visual_height > 0
	assert layout.visual_width > 0
	assert layout.height > 0
	assert layout.width > 0

	// Logical height is approximately line height.
	// Visual height typically includes ascenders/descenders specific to the glyphs.
	// For "Hello", it should be reasonably close to logical height, possibly smaller if no descenders.
	println('Logical WxH: ${layout.width}x${layout.height}')
	println('Visual  WxH: ${layout.visual_width}x${layout.visual_height}')

	// Ensure they are not exactly zero
	assert layout.visual_height >= 10.0 // 30px font should be > 10px tall
}
