module text_render

pub struct Context {
	ft_lib         &C.FT_LibraryRec
	pango_font_map &C.PangoFontMap
	pango_context  &C.PangoContext
}

// new_context initializes the global Pango and FreeType environment.
//
// Operations:
// 1. Boots FreeType.
// 2. Creates a Pango Font Map (based on FreeType/FontConfig).
// 3. Creates a root Pango Context.
//
// This context should be kept alive for the duration of the application.
// Passing this context to `layout_text` generates layouts that share the same font cache.
pub fn new_context() !&Context {
	// Initialize pointer to null
	mut ft_lib := &C.FT_LibraryRec(unsafe { nil })
	if C.FT_Init_FreeType(&ft_lib) != 0 {
		return error('Failed to initialize FreeType library')
	}

	pango_font_map := C.pango_ft2_font_map_new()
	if voidptr(pango_font_map) == unsafe { nil } {
		C.FT_Done_FreeType(ft_lib)
		return error('Failed to create Pango Font Map')
	}

	pango_context := C.pango_font_map_create_context(pango_font_map)
	if voidptr(pango_context) == unsafe { nil } {
		C.g_object_unref(pango_font_map)
		C.FT_Done_FreeType(ft_lib)
		return error('Failed to create Pango Context')
	}

	return &Context{
		ft_lib:         ft_lib
		pango_font_map: pango_font_map
		pango_context:  pango_context
	}
}

pub fn (mut ctx Context) free() {
	if voidptr(ctx.pango_context) != unsafe { nil } {
		C.g_object_unref(ctx.pango_context)
	}
	if voidptr(ctx.pango_font_map) != unsafe { nil } {
		C.g_object_unref(ctx.pango_font_map)
	}
	if voidptr(ctx.ft_lib) != unsafe { nil } {
		C.FT_Done_FreeType(ctx.ft_lib)
	}
}
