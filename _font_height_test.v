module vglyph

fn test_font_height_sanity() {
	mut ctx := new_context(1.0) or {
		assert false, 'Failed to create context'
		return
	}
	defer { ctx.free() }

	// Test with a standard font
	cfg := TextConfig{
		font_name: 'Sans 20'
	}

	height := ctx.font_height(cfg)
	// At 20 points, depending on dpi (96), we expect pixels ~ 20 * 1.33 = 26.6
	// Just check it's in a reasonable range (positive and > 0)
	assert height > 15.0
	assert height < 40.0

	println('Font height for Sans 20: ${height}')
}

fn test_font_height_pixels() {
	mut ctx := new_context(1.0)!
	defer { ctx.free() }

	// Test with pixel size
	cfg := TextConfig{
		font_name: 'Sans 20px'
	}

	height := ctx.font_height(cfg)
	// Should be close to 20px, maybe slightly larger due to line height/metrics
	assert height >= 18.0
	assert height <= 30.0

	println('Font height for Sans 20px: ${height}')
}
