module text_render

import gg

pub struct Layout {
pub mut:
	items      []Item
	char_rects []CharRect
}

pub struct CharRect {
pub:
	rect  gg.Rect
	index int // Byte index
}

pub struct Item {
pub:
	run_text string // Useful for debugging or if we need original text
	ft_face  &C.FT_FaceRec
	glyphs   []Glyph
	width    f64
	x        f64 // Run position relative to layout (x)
	y        f64 // Run position relative to layout (baseline y)
	color    gg.Color = gg.Color{255, 255, 255, 255}

	// Text Decoration
	has_underline           bool
	has_strikethrough       bool
	underline_offset        f64
	underline_thickness     f64
	strikethrough_offset    f64
	strikethrough_thickness f64
	has_overline            bool
	overline_offset         f64
	overline_thickness      f64

	// Background
	has_bg_color bool
	bg_color     gg.Color
	ascent       f64
	descent      f64
}

pub struct Glyph {
pub:
	index     u32
	x_offset  f64
	y_offset  f64
	x_advance f64
	y_advance f64
	codepoint u32 // Optional, might be 0 if not easily tracking back
}

pub struct TextConfig {
pub:
	font_name  string
	width      int            = -1 // in pixels, -1 or 0 for no limit
	align      PangoAlignment = .pango_align_left
	wrap       PangoWrapMode  = .pango_wrap_word
	use_markup bool
}

// layout_text performs the heavy lifting of shaping, wrapping, and arranging text using Pango.
//
// Algorithm Overview:
// 1. Creates a transient `PangoLayout` object which acts as the high-level representation of the paragraph.
// 2. Applies configuration: Width (for wrapping), Alignment, Font, and Markup.
// 3. Iterates through the layout results using `PangoLayoutIter` to decompose the text into visual "Run"s.
//    - A "Run" is a sequence of glyphs that share the same font, direction, and attributes.
// 4. Extracts detailed glyph info (index, position) from Pango and converts C structs to pure V `Item`s.
// 5. "Bakes" hit-testing data by querying the bounding box of every character index.
//
// Trade-offs:
// - **Performance**: This function does meaningful work (shaping is expensive). It should be called only when
//   text changes, not every frame. The result is a `Layout` struct that is cheap to draw repeatedly.
// - **Memory**: We duplicate some data (glyph indices, positions) into V structs to decouple life-cycle management
//   from Pango's C memory. This simplifies the API at the cost of slight memory overhead.
// - **Color**: We manually scrape Pango attributes to find colors. Pango doesn't apply colors to glyphs directly
//   but attaches them as metadata. We map these to `gg.Color` for the renderer to use during tinting.
pub fn (mut ctx Context) layout_text(text string, cfg TextConfig) !Layout {
	if text.len == 0 {
		return Layout{}
	}

	layout := setup_pango_layout(mut ctx, text, cfg) or { return err }
	defer { C.g_object_unref(layout) }

	iter := C.pango_layout_get_iter(layout)
	if iter == unsafe { nil } {
		return error('Failed to create Pango Layout Iterator')
	}
	defer { C.pango_layout_iter_free(iter) }

	mut items := []Item{}

	for {
		// PangoLayoutRun is a typedef for PangoGlyphItem
		run_ptr := C.pango_layout_iter_get_run_readonly(iter)
		if run_ptr != unsafe { nil } {
			// Explicit cast since V treats C.PangoGlyphItem and C.PangoLayoutRun as distinct types
			run := unsafe { &C.PangoLayoutRun(run_ptr) }
			item := process_run(run, iter, text)
			if item.glyphs.len > 0 {
				items << item
			}
		}

		if !C.pango_layout_iter_next_run(iter) {
			break
		}
	}

	char_rects := bake_hit_test_rects(layout, text)

	return Layout{
		items:      items
		char_rects: char_rects
	}
}

// Helper functions

// setup_pango_layout creates and configures a new PangoLayout object.
// It applies text, markup, wrapping, alignment, and font settings.
fn setup_pango_layout(mut ctx Context, text string, cfg TextConfig) !&C.PangoLayout {
	layout := C.pango_layout_new(ctx.pango_context)
	if layout == unsafe { nil } {
		return error('Failed to create Pango Layout')
	}

	if cfg.use_markup {
		C.pango_layout_set_markup(layout, text.str, text.len)
	} else {
		C.pango_layout_set_text(layout, text.str, text.len)
	}

	// Apply layout configuration
	if cfg.width > 0 {
		C.pango_layout_set_width(layout, cfg.width * pango_scale)
		C.pango_layout_set_wrap(layout, cfg.wrap)
	}
	C.pango_layout_set_alignment(layout, cfg.align)

	desc := C.pango_font_description_from_string(cfg.font_name.str)
	if desc != unsafe { nil } {
		C.pango_layout_set_font_description(layout, desc)
		C.pango_font_description_free(desc)
	}

	return layout
}

struct RunAttributes {
pub mut:
	color             gg.Color
	has_bg_color      bool
	bg_color          gg.Color
	has_underline     bool
	has_strikethrough bool
	has_overline      bool
}

// parse_run_attributes iterates through Pango attributes for a given item
// and extracts relevant visual properties like color and text decorations.
fn parse_run_attributes(pango_item &C.PangoItem) RunAttributes {
	mut attrs := RunAttributes{
		color:    gg.Color{255, 255, 255, 255}
		bg_color: gg.Color{0, 0, 0, 0}
	}

	// Iterate GSList of attributes
	mut curr_attr_node := unsafe { &C.GSList(pango_item.analysis.extra_attrs) }
	if curr_attr_node != unsafe { nil } {
		for {
			unsafe {
				if curr_attr_node == nil {
					break
				}
				attr := &C.PangoAttribute(curr_attr_node.data)
				attr_type := attr.klass.type

				if attr_type == .pango_attr_foreground {
					color_attr := &C.PangoAttrColor(attr)
					attrs.color = gg.Color{
						r: u8(color_attr.color.red >> 8)
						g: u8(color_attr.color.green >> 8)
						b: u8(color_attr.color.blue >> 8)
						a: 255
					}
				} else if attr_type == .pango_attr_background {
					color_attr := &C.PangoAttrColor(attr)
					attrs.has_bg_color = true
					attrs.bg_color = gg.Color{
						r: u8(color_attr.color.red >> 8)
						g: u8(color_attr.color.green >> 8)
						b: u8(color_attr.color.blue >> 8)
						a: 255
					}
				} else if attr_type == .pango_attr_underline {
					int_attr := &C.PangoAttrInt(attr)
					if int_attr.value != int(PangoUnderline.pango_underline_none) {
						attrs.has_underline = true
					}
				} else if attr_type == .pango_attr_strikethrough {
					int_attr := &C.PangoAttrInt(attr)
					if int_attr.value != 0 {
						attrs.has_strikethrough = true
					}
				} else if attr_type == .pango_attr_overline {
					int_attr := &C.PangoAttrInt(attr)
					if int_attr.value != int(PangoOverline.pango_overline_none) {
						attrs.has_overline = true
					}
				}
			}
			curr_attr_node = curr_attr_node.next
		}
	}
	return attrs
}

struct RunMetrics {
pub mut:
	und_pos      f64
	und_thick    f64
	strike_pos   f64
	strike_thick f64
	over_pos     f64
	over_thick   f64
}

// get_run_metrics fetches font metrics (position and thickness) for
// the active decorations (underline, strikethrough, overline) using Pango's font API.
fn get_run_metrics(pango_font &C.PangoFont, language &C.PangoLanguage, attrs RunAttributes) RunMetrics {
	mut m := RunMetrics{}
	if attrs.has_underline || attrs.has_strikethrough || attrs.has_overline {
		metrics := C.pango_font_get_metrics(pango_font, language)
		if metrics != unsafe { nil } {
			if attrs.has_underline {
				val_pos := C.pango_font_metrics_get_underline_position(metrics)
				val_thick := C.pango_font_metrics_get_underline_thickness(metrics)
				m.und_pos = f64(val_pos) / f64(pango_scale)
				m.und_thick = f64(val_thick) / f64(pango_scale)
				if m.und_thick < 1.0 {
					m.und_thick = 1.0
				}
				if m.und_pos < m.und_thick {
					m.und_pos = m.und_thick + 2.0
				}
			}
			if attrs.has_strikethrough {
				val_pos := C.pango_font_metrics_get_strikethrough_position(metrics)
				val_thick := C.pango_font_metrics_get_strikethrough_thickness(metrics)
				m.strike_pos = f64(val_pos) / f64(pango_scale)
				m.strike_thick = f64(val_thick) / f64(pango_scale)
				if m.strike_thick < 1.0 {
					m.strike_thick = 1.0
				}
			}
			if attrs.has_overline {
				val_ascent := C.pango_font_metrics_get_ascent(metrics)
				val_thick := C.pango_font_metrics_get_underline_thickness(metrics)
				m.over_pos = (f64(val_ascent) / f64(pango_scale)) - 3.0
				m.over_thick = f64(val_thick) / f64(pango_scale)
				if m.over_thick < 1.0 {
					m.over_thick = 1.0
				}
			}
			C.pango_font_metrics_unref(metrics)
		}
	}
	return m
}

// process_run takes a single Pango glyph run and converts it into a V `Item`.
// It handles attribute parsing, metric calculation, and glyph extraction.
fn process_run(run &C.PangoLayoutRun, iter &C.PangoLayoutIter, text string) Item {
	pango_item := run.item
	pango_font := pango_item.analysis.font
	if pango_font == unsafe { nil } {
		return Item{
			ft_face: unsafe { nil }
		}
	}

	ft_face := C.pango_ft2_font_get_face(pango_font)
	if ft_face == unsafe { nil } {
		return Item{
			ft_face: unsafe { nil }
		}
	}

	attrs := parse_run_attributes(pango_item)
	metrics := get_run_metrics(pango_font, pango_item.analysis.language, attrs)

	// Get logical extents for ascent/descent (used for background rect)
	logical_rect := C.PangoRectangle{}
	// We need ascent/descent relative to baseline.
	// run_x and run_y are logical POSITIONS (y is baseline)
	// logical_rect from get_run_extents is relative to layout origin (top-left)
	C.pango_layout_iter_get_run_extents(iter, unsafe { nil }, &logical_rect)

	run_x := f64(logical_rect.x) / f64(pango_scale)

	baseline_pango := C.pango_layout_iter_get_baseline(iter)
	ascent_pango := baseline_pango - logical_rect.y
	descent_pango := (logical_rect.y + logical_rect.height) - baseline_pango

	run_ascent := f64(ascent_pango) / f64(pango_scale)
	run_descent := f64(descent_pango) / f64(pango_scale)
	run_y := f64(baseline_pango) / f64(pango_scale)

	// Extract glyphs
	glyph_string := run.glyphs
	num_glyphs := glyph_string.num_glyphs
	mut glyphs := []Glyph{cap: num_glyphs}
	mut width := f64(0)
	infos := glyph_string.glyphs

	for i in 0 .. num_glyphs {
		unsafe {
			info := infos[i]
			x_off := f64(info.geometry.x_offset) / f64(pango_scale)
			y_off := f64(info.geometry.y_offset) / f64(pango_scale)
			x_adv := f64(info.geometry.width) / f64(pango_scale)
			y_adv := 0.0

			glyphs << Glyph{
				index:     info.glyph
				x_offset:  x_off
				y_offset:  y_off
				x_advance: x_adv
				y_advance: y_adv
				codepoint: 0
			}
			width += x_adv
		}
	}

	// Get sub-text
	start_index := pango_item.offset
	length := pango_item.length
	run_str := unsafe { (text.str + start_index).vstring_with_len(length) }

	return Item{
		run_text:                run_str
		ft_face:                 ft_face
		glyphs:                  glyphs
		width:                   width
		x:                       run_x
		y:                       run_y
		color:                   attrs.color
		has_underline:           attrs.has_underline
		has_strikethrough:       attrs.has_strikethrough
		underline_offset:        metrics.und_pos
		underline_thickness:     metrics.und_thick
		strikethrough_offset:    metrics.strike_pos
		strikethrough_thickness: metrics.strike_thick
		has_overline:            attrs.has_overline
		overline_offset:         metrics.over_pos
		overline_thickness:      metrics.over_thick
		has_bg_color:            attrs.has_bg_color
		bg_color:                attrs.bg_color
		ascent:                  run_ascent
		descent:                 run_descent
	}
}

// bake_hit_test_rects iterates through the text and generates bounding boxes
// for every character to enable efficient hit testing later.
fn bake_hit_test_rects(layout &C.PangoLayout, text string) []CharRect {
	mut char_rects := []CharRect{}
	mut i := 0
	for i < text.len {
		pos := C.PangoRectangle{}
		C.pango_layout_index_to_pos(layout, i, &pos)

		mut final_x := f32(pos.x) / f32(pango_scale)
		mut final_y := f32(pos.y) / f32(pango_scale)
		mut final_w := f32(pos.width) / f32(pango_scale)
		mut final_h := f32(pos.height) / f32(pango_scale)

		if final_w < 0 {
			final_x += final_w
			final_w = -final_w
		}
		if final_h < 0 {
			final_y += final_h
			final_h = -final_h
		}

		char_rects << CharRect{
			rect:  gg.Rect{
				x:      final_x
				y:      final_y
				width:  final_w
				height: final_h
			}
			index: i
		}

		// Iterate runes manually
		mut step := 1
		b := text[i]
		if b >= 0xF0 {
			step = 4
		} else if b >= 0xE0 {
			step = 3
		} else if b >= 0xC0 {
			step = 2
		}
		i += step
	}
	return char_rects
}

// hit_test returns the byte index of the character at (x, y) relative to the layout origin.
// Returns -1 if no character is found close enough.
//
// Algorithm:
// Performs a simple linear search (O(N)) over the baked character rectangles.
//
// Trade-offs:
// - **Efficiency**: For typical paragraphs (N < 1000), linear search is cache-friendly and faster than overhead
//   of building a QuadTree. For extremely large texts (e.g., entire documents laid out at once),
//   this standard vector linear scan might become noticeable, but usually mouse events are sparse.
// - **Accuracy**: Returns the *first* matching index. In cases of overlapping characters (rendering artifacts),
//   order matters. We search in logical order.
pub fn (l Layout) hit_test(x f32, y f32) int {
	// Simple linear search.
	// We could optimize with spatial partitioning if needed.
	for cr in l.char_rects {
		if x >= cr.rect.x && x <= cr.rect.x + cr.rect.width && y >= cr.rect.y
			&& y <= cr.rect.y + cr.rect.height {
			return cr.index
		}
	}
	return -1
}
