module main

import vglyph
import gg

struct App {
mut:
	ctx      &gg.Context      = unsafe { nil }
	renderer &vglyph.Renderer = unsafe { nil }
}

fn main() {
	println('Starting Atlas Resize Debug...')
	mut app := &App{}
	app.ctx = gg.new_context(
		bg_color:     gg.white
		width:        800
		height:       600
		window_title: 'Glyph Atlas Resize Debug'
		init_fn:      init
		user_data:    app
	)
	app.ctx.run()
}

fn init(mut app App) {
	println('Context initialized. Creating renderer...')
	// Start with a very small atlas to force resize shortly
	// 128x128 atlas.
	app.renderer = vglyph.new_renderer_atlas_size(mut app.ctx, 128, 128)

	initial_height := app.renderer.get_atlas_height()
	println('Initial atlas height: ${initial_height}')

	// Fill up the atlas
	// Let's add many bitmaps of 20px height
	for i in 0 .. 50 {
		// Create a fake bitmap (100x20)
		bmp := vglyph.Bitmap{
			width:    100
			height:   20
			channels: 4
			data:     []u8{len: 100 * 20 * 4}
		}

		// This should trigger resize eventually
		app.renderer.debug_insert_bitmap(bmp, 0, 0) or {
			println('Failed to insert bitmap ${i}: ${err}')
			return
		}
	}

	final_height := app.renderer.get_atlas_height()
	println('Final atlas height: ${final_height}')

	if final_height > initial_height {
		println('SUCCESS: Atlas resized from ${initial_height} to ${final_height}')
	} else {
		println('WARNING: Atlas did not resize (maybe it fit?)')
	}

	exit(0)
}
