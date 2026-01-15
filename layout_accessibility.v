module vglyph

import gg
import strings
import accessibility

// update_accessibility takes a Layout and converts it into accessibility nodes,
// essentially "publishing" the visual structure to the screen reader.
// This accumulates nodes for the current frame. Call am.commit() to push changes.
pub fn update_accessibility(mut am accessibility.AccessibilityManager, l Layout, origin_x f32, origin_y f32) {
	// Process Lines
	for line in l.lines {
		// Only create nodes for lines that have content
		if line.length == 0 {
			continue
		}

		line_text := extract_text(l, line.start_index, line.length)

		rect := gg.Rect{
			x:      origin_x + line.rect.x
			y:      origin_y + line.rect.y
			width:  line.rect.width
			height: line.rect.height
		}

		am.add_text_node(line_text, rect)
	}
}

// Helper to extract text string from layout items
fn extract_text(l Layout, start int, length int) string {
	mut res := strings.new_builder(length)
	end := start + length

	for item in l.items {
		item_end := item.start_index + item.length

		if item_end <= start {
			continue
		}
		if item.start_index >= end {
			break
		}

		res.write_string(item.run_text)
	}
	return res.str()
}
