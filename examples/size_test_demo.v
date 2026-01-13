module main

import vglyph

fn check_font_size_override() {
	mut ctx := vglyph.new_context(1.0) or { panic(err) }
	defer { ctx.free() }

	// Case 1: Standard size in font name
	cfg_small := vglyph.TextConfig{
		font_name: 'Sans 10'
		size:      0 // Should use 10
	}
	height_small := ctx.font_height(cfg_small)
	println('Height Small (10pt): ${height_small}')

	// Case 2: Size in font name overridden by size field
	cfg_large := vglyph.TextConfig{
		font_name: 'Sans 10'
		size:      20.0 // Should override to 20
	}
	height_large := ctx.font_height(cfg_large)
	println('Height Large (20pt): ${height_large}')

	if height_large > height_small {
		println('PASS: height_large > height_small')
	} else {
		println('FAIL: height_large <= height_small')
	}

	// Case 3: Fractional size
	cfg_fractional := vglyph.TextConfig{
		font_name: 'Sans 10'
		size:      15.5
	}
	height_fractional := ctx.font_height(cfg_fractional)
	println('Height Fractional (15.5pt): ${height_fractional}')

	if height_fractional > height_small && height_fractional < height_large {
		println('PASS: height_fractional is between small and large')
	} else {
		println('FAIL: height_fractional check')
	}
}

fn check_layout_rich_text_size() {
	mut ctx := vglyph.new_context(1.0) or { panic(err) }
	defer { ctx.free() }

	text := vglyph.RichText{
		runs: [
			vglyph.StyleRun{
				text:  'Small '
				style: vglyph.RichTextStyle{
					font_name: 'Sans 10'
				}
			},
			vglyph.StyleRun{
				text:  'Large '
				style: vglyph.RichTextStyle{
					font_name: 'Sans 10'
					size:      30.0
				}
			},
			vglyph.StyleRun{
				text:  'Default '
				style: vglyph.RichTextStyle{
					size: 20.0
				}
			},
		]
	}

	layout := ctx.layout_rich_text(text, vglyph.TextConfig{ font_name: 'Sans 12' }) or {
		panic(err)
	}

	println('Checking layout items...')
	for i, item in layout.items {
		total_height := item.ascent + item.descent
		println('Item ${i} Height: ${total_height}')
	}

	if layout.items.len >= 3 {
		h0 := layout.items[0].ascent + layout.items[0].descent
		h1 := layout.items[1].ascent + layout.items[1].descent
		if h1 > h0 * 2.0 {
			println('PASS: Large item is significantly larger')
		} else {
			println('FAIL: Large item size check')
		}
	} else {
		println('FAIL: Not enough items in layout')
	}
}

fn main() {
	println('Running tests...')
	check_font_size_override()
	check_layout_rich_text_size()
	println('Done.')
}
