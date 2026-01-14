module vglyph

import gg as _

// Test context creation and cleanup
fn test_context_creation() {
	mut ctx := new_context(1.0) or {
		assert false, 'Failed to create context: ${err}'
		return
	}
	ctx.free()
}

// Test basic layout generation
fn test_layout_simple_text() {
	mut ctx := new_context(1.0)!
	defer { ctx.free() }

	cfg := TextConfig{
		style: TextStyle{
			font_name: 'Sans 20'
		}
		block: BlockStyle{
			width: -1
			align: .left
		}
	}

	layout := ctx.layout_text('Hello World', cfg)!

	// Should have items
	assert layout.items.len > 0

	// Should have char rects equal to text length
	assert layout.char_rects.len == 'Hello World'.len

	// Check content of first item
	$if debug {
		assert layout.items[0].run_text == 'Hello World'
	}
}

// Test empty text
fn test_layout_empty_text() {
	mut ctx := new_context(1.0)!
	defer { ctx.free() }

	cfg := TextConfig{
		style: TextStyle{
			font_name: 'Sans 20'
		}
	}

	layout := ctx.layout_text('', cfg)!

	assert layout.items.len == 0
	assert layout.char_rects.len == 0
}

// Test wrapping
fn test_layout_wrapping() {
	mut ctx := new_context(1.0)!
	defer { ctx.free() }

	cfg := TextConfig{
		style: TextStyle{
			font_name: 'Sans 20'
		}
		block: BlockStyle{
			width: 50
			wrap:  .word
		}
	}

	text := 'This is a long text that should wrap'
	layout := ctx.layout_text(text, cfg)!

	assert layout.items.len > 1
}

// Test hit testing
fn test_hit_test() {
	mut ctx := new_context(1.0)!
	defer { ctx.free() }

	cfg := TextConfig{
		style: TextStyle{
			font_name: 'Sans 20'
		}
		block: BlockStyle{
			width: -1
		}
	}

	// "A" is clearly at 0,0
	layout := ctx.layout_text('A', cfg)!

	// Test hit at middle of first char
	index := layout.hit_test(5, 5)

	assert index == 0

	// Test miss
	miss_index := layout.hit_test(-10, -10)
	assert miss_index == -1
}

// Test markup
fn test_layout_markup() {
	mut ctx := new_context(1.0)!
	defer { ctx.free() }

	cfg := TextConfig{
		style:      TextStyle{
			font_name: 'Sans 20'
		}
		use_markup: true
	}

	// Text with color
	text := '<span foreground="#FF0000">Red</span>'
	layout := ctx.layout_text(text, cfg)!

	assert layout.items.len > 0

	// Check color of first item
	item := layout.items[0]
	// Correct color should be Red (255, 0, 0, 255)
	assert item.color.r == 255
	assert item.color.g == 0
	assert item.color.b == 0
}

// Test hit test rect
fn test_hit_test_rect() {
	mut ctx := new_context(1.0)!
	defer { ctx.free() }

	cfg := TextConfig{
		style: TextStyle{
			font_name: 'Sans 20'
		}
		block: BlockStyle{
			width: -1
		}
	}

	layout := ctx.layout_text('A', cfg)!

	// Test hit at middle of first char
	rect := layout.hit_test_rect(5, 5) or {
		assert false, 'Should have hit'
		return
	}

	// Basic validation that we got a reasonable rect
	assert rect.width > 0
	assert rect.height > 0

	// Test miss
	if _ := layout.hit_test_rect(-10, -10) {
		assert false, 'Should have missed'
	}
}
