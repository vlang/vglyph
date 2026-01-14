module vglyph

// Darwin (macOS) implementation of the AccessibilityBackend.
// This file is only compiled on macOS.

@[if darwin]
struct DarwinAccessibilityBackend {
mut:
	elements map[int]Id // node_id -> NSAccessibilityElement*
	window   Id
}

fn get_role_string(role AccessibilityRole) Id {
	match role {
		.text { return ns_string('AXStaticText') }
		.container { return ns_string('AXGroup') }
		else { return ns_string('AXUnknown') }
	}
}

fn (mut b DarwinAccessibilityBackend) get_window() Id {
	return unsafe { nil }
	/*
	if b.window == unsafe { nil } {
		b.window = sapp.macos_get_window()
	}
	return b.window
	*/
}

fn (mut b DarwinAccessibilityBackend) update_tree(nodes map[int]AccessibilityNode, root_id int) {
	window := b.get_window()
	if window == unsafe { nil } {
		return
	}

	unsafe {
		// 1. Create/Update Elements
		for node_id, node in nodes {
			if node_id !in b.elements {
				b.elements[node_id] = b.create_element(node.role)
			}
			_ := b.elements[node_id]
			// elem := b.elements[node_id]

			// Set Label (Commented out due to runtime stability issues)
			// label_ns := ns_string(node.text)
			// C.v_msgSend_void_id(elem, sel_register_name('setAccessibilityLabel:'), label_ns)

			// Set Frame (Commented out)
			/*
			win_frame := get_window_frame(window)
			screen_y := win_frame.origin.y + win_frame.size.height - f64(node.rect.y) - f64(node.rect.height)
				
			ns_rect := make_ns_rect(
				f32(win_frame.origin.x + f64(node.rect.x)),
				f32(screen_y),
				f32(node.rect.width),
				f32(node.rect.height)
			)
			C.v_msgSend_setFrame(elem, sel_register_name('setAccessibilityFrame:'), ns_rect)
			*/
		}

		// 2. Build Hierarchy (Commented out)
		/*
		for node_id, node in nodes {
			elem := b.elements[node_id]
			
			// Set Parent
			parent_id := node.parent
			if parent_id != -1 {
				if parent_elem := b.elements[parent_id] {
					C.v_msgSend_void_id(elem, sel_register_name('setAccessibilityParent:'), parent_elem)
				}
			} else {
				// Root's parent is Window
				if window != voidptr(0) {
					C.v_msgSend_void_id(elem, sel_register_name('setAccessibilityParent:'), window)
				}
			}
			
			// Set Children
			if node.children.len > 0 {
				children_ns := ns_mutable_array_new()
				for child_id in node.children {
					if child_elem := b.elements[child_id] {
						ns_array_add_object(children_ns, child_elem)
					}
				}
				C.v_msgSend_void_id(elem, sel_register_name('setAccessibilityChildren:'), children_ns)
			}
		}
		
		// 3. Attach Root to Window
		if window != voidptr(0) {
			if root_elem := b.elements[root_id] {
				root_array := ns_mutable_array_new()
				ns_array_add_object(root_array, root_elem)
				C.v_msgSend_void_id(window, sel_register_name('setAccessibilityChildren:'), root_array)
			}
		}
		*/
	}
}

fn (mut b DarwinAccessibilityBackend) create_element(role AccessibilityRole) Id {
	unsafe {
		cls := C.v_objc_getClass(c'NSAccessibilityElement')
		if cls == nil {
			return nil
		}

		alloc_sel := sel_register_name('alloc')
		init_sel := sel_register_name('init')

		alloc_obj := C.v_msgSend_0(cls, alloc_sel)
		obj := C.v_msgSend_0(alloc_obj, init_sel)

		// Set Role
		role_val := get_role_string(role)
		role_sel := sel_register_name('setAccessibilityRole:')
		C.v_msgSend_void_id(obj, role_sel, role_val)

		return obj
	}
}

fn (mut b DarwinAccessibilityBackend) set_focus(node_id int) {
	// TODO
}

// Helpers
fn get_window_frame(window Id) C.NSRect {
	return C.v_msgSend_nsrect(window, sel_register_name('frame'))
}
