module main

import vglyph
import gg

const quality_win_width = 1000
const quality_win_height = 800

struct QualityApp {
mut:
	ctx         &gg.Context     = unsafe { nil }
	text_system &vglyph.Context = unsafe { nil }

	// We need multiple renderers or modify one?
	// Modifying one renderer mid-frame is risky if it shares the atlas,
	// because changing settings requires re-caching glyphs.
	// `set_text_quality` clears the cache.
	// So we can draw scene in passes, or use multiple renderers (each with own atlas).
	// Let's use multiple renderers to easily compare side-by-side without cache thrashing per frame.
	renderer_std   &vglyph.Renderer = unsafe { nil }
	renderer_lcd   &vglyph.Renderer = unsafe { nil }
	renderer_gamma &vglyph.Renderer = unsafe { nil }
}

fn main() {
	mut app := &QualityApp{}
	app.ctx = gg.new_context(
		bg_color:     gg.white
		width:        quality_win_width
		height:       quality_win_height
		window_title: 'Text Quality Verification'
		frame_fn:     frame
		init_fn:      init
		user_data:    app
	)
	app.ctx.run()
}

fn init(mut app QualityApp) {
	app.text_system = vglyph.new_context() or { panic(err) }

	// 1. Standard Renderer (Defaults)
	app.renderer_std = vglyph.new_renderer(mut app.ctx)

	// 2. LCD Renderer (LCD Hinting, Default Gamma)
	app.renderer_lcd = vglyph.new_renderer(mut app.ctx)
	app.renderer_lcd.set_text_quality(vglyph.TextQualityConfig{
		use_lcd:           true
		alpha_exponential: 0.4545 // Standard
	})

	// 3. Custom Gamma Renderer (LCD Hinting, Tuned Gamma)
	// Try a different gamma, e.g., slightly darker/lighter?
	// If 0.4545 (1/2.2) is standard, maybe 1.0 (linear)? Or 0.6?
	app.renderer_gamma = vglyph.new_renderer(mut app.ctx)
	app.renderer_gamma.set_text_quality(vglyph.TextQualityConfig{
		use_lcd:           true
		alpha_exponential: 0.6
	})
}

fn frame(mut app QualityApp) {
	app.ctx.begin()
	app.draw()
	app.ctx.end()

	app.renderer_std.commit()
	app.renderer_lcd.commit()
	app.renderer_gamma.commit()
}

fn (mut app QualityApp) draw() {
	sizes := [10, 11, 12, 14, 16, 24]

	mut y_pos := f32(40.0)
	x_col1 := f32(20.0)
	x_col2 := f32(350.0)
	x_col3 := f32(680.0)

	app.draw_header(x_col1, y_pos, 'Standard (Light Hinting)')
	app.draw_header(x_col2, y_pos, 'LCD Hinting (Gamma 2.2)')
	app.draw_header(x_col3, y_pos, 'LCD Hinting (Gamma Exp 0.6)')

	y_pos += 40.0

	for size in sizes {
		text := 'Quick Brown Fox (${size}px)'
		cfg := vglyph.TextConfig{
			font_name: 'Arial ${size}'
			color:     gg.black
		}

		// Col 1
		l1 := app.text_system.layout_text(text, cfg) or { panic(err) }
		app.renderer_std.draw_layout(l1, x_col1, y_pos)

		// Col 2
		l2 := app.text_system.layout_text(text, cfg) or { panic(err) }
		app.renderer_lcd.draw_layout(l2, x_col2, y_pos)

		// Col 3
		l3 := app.text_system.layout_text(text, cfg) or { panic(err) }
		app.renderer_gamma.draw_layout(l3, x_col3, y_pos)

		y_pos += app.renderer_std.max_visual_height(l1) + 20.0
	}

	// Instructions
	// app.ctx.draw_text(20, 750, 'Check artifacts/screenshots for comparison. User reported "Heavy and Soft". LCD should fix Soft. Gamma tuning fixes Heavy.')
}

fn (mut app QualityApp) draw_header(x f32, y f32, text string) {
	cfg := vglyph.TextConfig{
		font_name: 'Arial 16'
		color:     gg.Color{
			r: 100
			g: 100
			b: 100
			a: 255
		}
	}
	l := app.text_system.layout_text(text, cfg) or { panic(err) }
	app.renderer_std.draw_layout(l, x, y)
}
