module main

import gg
import vglyph

const window_width = 800
const window_height = 600

struct EditorApp {
mut:
	gg &gg.Context
	ts &vglyph.TextSystem

	text   string
	cfg    vglyph.TextConfig
	layout vglyph.Layout

	cursor_idx   int
	select_start int
	is_dragging  bool
}

fn main() {
	mut app := &EditorApp{
		gg:           unsafe { nil }
		ts:           unsafe { nil }
		text:         'Hello VGlyph Editor!\n\nThis is a demo of the new cursor positioning and selection logic.\n\nTry clicking anywhere to move the red cursor.\nClick and drag to select text (blue highlight).\n\nIt handles:\n- Multiline text\n- Variable width fonts\n- Empty lines\n- Margins and padding'
		select_start: -1
	}

	app.gg = gg.new_context(
		bg_color:     gg.white
		width:        window_width
		height:       window_height
		window_title: 'VGlyph Editor Demo'
		init_fn:      init
		frame_fn:     frame
		event_fn:     event
		user_data:    app
	)

	app.gg.run()
}

fn init(mut app EditorApp) {
	app.ts = vglyph.new_text_system(mut app.gg) or { panic(err) }

	app.cfg = vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'Sans 16'
			color:     gg.black
		}
		block: vglyph.BlockStyle{
			width: 600
			wrap:  .word
		}
	}

	// Perform initial layout
	// We access the context directly to get the layout object for logical operations
	// In a real app, you might cache this
	app.layout = app.ts.layout_text(app.text, app.cfg) or { panic(err) }
}

fn event(e &gg.Event, mut app EditorApp) {
	// Offset for rendering (x=50, y=50)
	offset_x := f32(50)
	offset_y := f32(50)

	match e.typ {
		.mouse_down {
			mx := e.mouse_x - offset_x
			my := e.mouse_y - offset_y

			// Get index closest to click
			idx := app.layout.get_closest_offset(mx, my)
			app.cursor_idx = idx
			app.select_start = idx
			app.is_dragging = true
		}
		.mouse_up {
			app.is_dragging = false
		}
		.mouse_move {
			if app.is_dragging {
				mx := e.mouse_x - offset_x
				my := e.mouse_y - offset_y
				idx := app.layout.get_closest_offset(mx, my)
				app.cursor_idx = idx
			}
		}
		else {}
	}
}

fn frame(mut app EditorApp) {
	app.gg.begin()

	// Draw Text
	offset_x := f32(50)
	offset_y := f32(50)

	// Draw Selection Backgrounds
	if app.select_start != -1 && app.cursor_idx != app.select_start {
		start := if app.select_start < app.cursor_idx { app.select_start } else { app.cursor_idx }
		end := if app.select_start < app.cursor_idx { app.cursor_idx } else { app.select_start }

		rects := app.layout.get_selection_rects(start, end)
		for r in rects {
			app.gg.draw_rect_filled(offset_x + r.x, offset_y + r.y, r.width, r.height,
				gg.Color{50, 50, 200, 100})
		}
	}

	// Render the text using the system
	app.ts.draw_text(offset_x, offset_y, app.text, app.cfg) or { println(err) }

	// Draw Cursor
	// To draw cursor, we need the position of the character at cursor_idx.
	// We can cheat by using get_selection_rects for a single char or hit_test_rect?
	// Actually, closest_offset returns index. We need "index to rect".
	// We can iterate char_rects.

	// Simple linear scan for cursor pos (optimization: add get_cursor_pos to Layout)
	mut cx := f32(0)
	mut cy := f32(0)
	mut found := false

	for line in app.layout.lines {
		// If cursor is on this line range?
		// Note: cursor_idx might be == length (end of text)
		if app.cursor_idx >= line.start_index && app.cursor_idx <= line.start_index + line.length {
			// Find char
			for cr in app.layout.char_rects {
				if cr.index == app.cursor_idx {
					cx = cr.rect.x
					cy = cr.rect.y
					found = true
					break
				}
			}
			// If not found (e.g. newline or end of line), take right edge of previous char or left of line
			if !found {
				// Logic for end of line cursor
				if app.cursor_idx == line.start_index + line.length {
					// It is at the end of this line
					// Use line rect end
					cx = line.rect.x + line.rect.width
					cy = line.rect.y
					found = true
				}
			}
		}
		if found {
			break
		}
	}

	// Fallback if at very end or start
	if !found && app.layout.lines.len > 0 {
		last_line := app.layout.lines.last()
		if app.cursor_idx >= last_line.start_index + last_line.length {
			cx = last_line.rect.x + last_line.rect.width
			cy = last_line.rect.y
		} else if app.cursor_idx == 0 {
			first_line := app.layout.lines[0]
			cx = first_line.rect.x
			cy = first_line.rect.y
		}
	}

	// Draw cursor line
	if app.layout.lines.len > 0 {
		// rough height estimate
		h := app.layout.lines[0].rect.height
		app.gg.draw_rect_filled(offset_x + cx, offset_y + cy, 2, h, gg.red)
	}

	app.gg.end()
	app.ts.commit()
}
