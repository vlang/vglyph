module main

import gg
import vglyph

struct EmojiApp {
mut:
	ctx &gg.Context
	ts  &vglyph.TextSystem
}

fn main() {
	mut app := &EmojiApp{
		ctx: unsafe { nil }
		ts:  unsafe { nil }
	}

	app.ctx = gg.new_context(
		width:         800
		height:        600
		bg_color:      gg.white
		create_window: true
		window_title:  'Emoji Scaling Test'
		frame_fn:      frame
		user_data:     app
		init_fn:       init
	)

	app.ctx.run()
}

fn init(mut app EmojiApp) {
	app.ts = vglyph.new_text_system(mut app.ctx) or { panic(err) }

	// Load Apple Color Emoji on macOS
	// Note: Path depends on OS, assuming macOS based on user info
	path := '/System/Library/Fonts/Apple Color Emoji.ttc'
	if !app.ts.add_font_file(path) {
		println('Warning: Could not load Apple Color Emoji. Ensure path is correct.')
	}
}

fn frame(mut app EmojiApp) {
	app.ctx.begin()

	// Text with Emojis
	// Using "Apple Color Emoji" as font family if loaded, or fallback
	// Often system fallback handles it, but explicit checks help.
	// Mixing text and emoji.

	// Large Text
	app.ts.draw_text(50, 50, 'Hello 🍎 World 🚀', vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'Sans 32'
			color:     gg.black
		}
	}) or { panic(err) }

	// Medium Text
	app.ts.draw_text(50, 120, 'Text logic: ⚛️ + ⚡ = 🔥', vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'Sans 24'
			color:     gg.black
		}
	}) or { panic(err) }

	// Small Text
	app.ts.draw_text(50, 180, 'Small emojis: 🐜🍎🍎🍎🍎', vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'Sans 16'
			color:     gg.black
		}
	}) or { panic(err) }

	// Baseline Reference Lines
	app.ctx.draw_line(40, 50 + 32, 600, 50 + 32, gg.red) // Approximate baseline for 32px (top-left coords? no, vglyph draws from baseline?)
	// vglyph.draw_text (x,y) behavior:
	// "Item.y is BASELINE y" in render code.
	// But `draw_text` usually takes top-left or similar?
	// In renderer.v: `mut cy := y + f32(item.y) // Baseline`.
	// And `item.y` comes from Pango layout.
	// Typically `ts.draw_text` takes (x, y) as top-left of the layout box.
	// We'll see visually.

	app.ts.commit()
	app.ctx.end()
}
