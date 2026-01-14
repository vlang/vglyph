module main

import vglyph
import gg

const window_width = 800
const window_height = 600

struct App {
mut:
	ts &vglyph.TextSystem = unsafe { nil }
	gg &gg.Context        = unsafe { nil }
}

fn main() {
	mut app := &App{}
	app.gg = gg.new_context(
		width:         window_width
		height:        window_height
		create_window: true
		window_title:  'Accessibility Simple Demo'
		user_data:     app
		bg_color:      gg.white
		frame_fn:      frame
		init_fn:       init
	)
	app.gg.run()
}

fn init(mut app App) {
	app.ts = vglyph.new_text_system(mut app.gg) or { panic(err) }

	// Enable automatic accessibility updates
	app.ts.enable_accessibility(true)
}

fn frame(mut app App) {
	app.gg.begin()

	// Text 1
	app.ts.draw_text(50, 50, 'Hello Accessibility!', vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'Roboto 24'
			color:     gg.black
		}
	}) or { panic(err) }

	// Text 2
	app.ts.draw_text(50, 100, 'This is a second line.', vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'Roboto 18'
			color:     gg.gray
		}
	}) or { panic(err) }

	// Text 3
	app.ts.draw_text(50, 150, 'Both lines should be in the accessible tree.', vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'Roboto 18'
			color:     gg.blue
		}
	}) or { panic(err) }

	// Commit (pushes accessibility tree)
	app.ts.commit()

	app.gg.end()
}
