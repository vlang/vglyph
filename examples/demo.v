module main

import gg
import text_render
import os

struct App {
mut:
	ctx    &gg.Context
	tr_ctx &text_render.Context
	renderer &text_render.Renderer
	layout text_render.Layout
}

fn main() {
	mut app := &App{
		ctx: unsafe { nil }
		tr_ctx: unsafe { nil }
		renderer: unsafe { nil }
	}
	app.ctx = gg.new_context(
		bg_color: gg.Color{255, 255, 255, 255}
		width: 800
		height: 600
		create_window: true
		window_title: 'V Text Render Engine'
		frame_fn: frame
		user_data: app
		init_fn: init
	)
	app.ctx.run()
}

fn init(mut app App) {
	app.tr_ctx = text_render.new_context() or { panic(err) }
	
	// Define fonts to try. 
	// Please ensure these exist or change logic to pick available fonts.
	// Using downloaded Noto fonts
	wd := os.getwd()
	base_path := if os.exists(os.join_path(wd, 'assets/fonts')) {
		wd
	} else if os.exists(os.join_path(wd, '../assets/fonts')) {
		os.join_path(wd, '..')
	} else {
		wd
	}
	
	fonts := [
		FontDef{'arial', os.join_path(base_path, 'assets/fonts/NotoSans-Regular.ttf')},
		FontDef{'arabic', os.join_path(base_path, 'assets/fonts/NotoSansArabic-Regular.ttf')},
		FontDef{'japanese', os.join_path(base_path, 'assets/fonts/NotoSansCJKjp-Regular.otf')},
		FontDef{'emoji', os.join_path(base_path, 'assets/fonts/NotoColorEmoji.ttf')},
	]
	
	mut loaded_names := []string{}
	
	for f in fonts {
		if os.exists(f.path) {
			println('Loading $f.name from $f.path')
			if f.name == 'emoji' {
				app.tr_ctx.load_font(f.name, f.path, 100) or { println('Failed to load $f.name') continue }
			} else {
				app.tr_ctx.load_font(f.name, f.path, 40) or { println('Failed to load $f.name') continue }
			}
			loaded_names << f.name
		} else {
			println('Font not found: $f.path')
		}
	}
	
	text := "Hello السلام Verden 🌍" 
	
	app.layout = app.tr_ctx.layout_text(text, loaded_names)
	
	app.renderer = text_render.new_renderer(app.ctx)
}

struct FontDef {
	name string
	path string
}

fn frame(mut app App) {
	app.ctx.begin()
	// Debug: Simple rectangle to prove drawing works
	app.ctx.draw_rect_filled(10, 10, 100, 100, gg.Color{0, 0, 255, 255})
	
	// Check if renderer is initialized
	if unsafe { app.renderer != 0 } {
		app.renderer.draw_layout(app.layout, 50, 300)
	}
	app.ctx.end()
}
