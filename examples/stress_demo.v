module main

import gg
import vglyph

struct AppStress {
mut:
	ctx        &gg.Context        = unsafe { nil }
	ts         &vglyph.TextSystem = unsafe { nil }
	scroll_y   f32
	max_scroll f32
}

fn frame(mut app AppStress) {
	app.ctx.begin()
	app.ctx.draw_rect_filled(0, 0, app.ctx.width, app.ctx.height, gg.white)

	// Apply scroll
	app.ctx.draw_rect_empty(0, 0, 0, 0, gg.white) // Dummy call to reset state if needed? Not really needed in gg usually.

	cfg := vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'Sans 20'
			color:     gg.black
		}
	}

	cols := 20
	total_chars := 6000
	start_code := 0x21 // Start from '!'

	col_width := f32(40.0)
	row_height := f32(30.0)

	rows := (total_chars + cols - 1) / cols
	content_height := rows * row_height
	app.max_scroll = if content_height > app.ctx.height {
		content_height - app.ctx.height + 50
	} else {
		0
	}

	// Draw valid range based on scroll to avoid rendering everything if not needed?
	// The prompt implies "renders 6000 different characters" to "test the limits".
	// So we should try to render them all to test the robustness of the system (e.g. hitting atlas limits).
	// However, we can simply iterate and draw. vglyph might cull, or not.
	// Let's just draw them all to hit the "stress test" requirement hard.

	// Adjust for scroll
	start_y := 50 - app.scroll_y

	for i in 0 .. total_chars {
		r := i / cols
		c := i % cols

		code := start_code + i
		// Simple safe-guard against control chars if needed, but 0x21+ is mostly fine until higher ranges.
		// Just cast to rune.
		text := rune(code).str()

		x := 50 + c * col_width
		y := start_y + r * row_height

		// Simple culling optimization for visual sanity, but maybe we want to force render?
		// "renders 6000 different characters... to test the limits"
		// If I cull manually, I'm testing my culling logic, not vglyph's rendering limits.
		// But if I don't cull, I might just be drawing off screen.
		// Let's draw everything to potentiallly flood the command buffer/atlas.

		app.ts.draw_text(x, y, text, cfg) or {
			// Ignore errors for individual glyphs (e.g. missing glyphs in font)
			continue
		}
	}

	// Performance info
	app.ts.draw_text(10, 10, 'FPS: ${app.ctx.frame}', vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'Sans 20'
			color:     gg.red
		}
	}) or {}

	app.ts.draw_text(10, 40, 'Scroll: ${int(app.scroll_y)} / ${int(app.max_scroll)}',
		vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'Sans 20'
			color:     gg.blue
		}
	}) or {}

	app.ts.commit()
	app.ctx.end()
}

fn init(mut app AppStress) {
	app.ts = vglyph.new_text_system(mut app.ctx) or { panic(err) }
}

fn on_event(e &gg.Event, mut app AppStress) {
	if e.typ == .mouse_scroll {
		app.scroll_y -= e.scroll_y * 20
		if app.scroll_y < 0 {
			app.scroll_y = 0
		}
		if app.scroll_y > app.max_scroll {
			app.scroll_y = app.max_scroll
		}
	}
}

fn main() {
	mut app := &AppStress{}
	app.ctx = gg.new_context(
		width:         900
		height:        700
		window_title:  'Stress Test: 6000 Characters'
		create_window: true
		bg_color:      gg.white
		ui_mode:       true
		user_data:     app
		frame_fn:      frame
		init_fn:       init
		event_fn:      on_event
	)

	app.ctx.run()
}
