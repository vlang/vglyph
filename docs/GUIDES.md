# vglyph Guides

This document covers common use-cases and deep dives into specific features.

## Rich Text Markup

`vglyph` leverages [Pango Markup](https://docs.gtk.org/Pango/pango_markup.html)
to support rich styling within a single string.

To use markup, you **must** set `use_markup: true` in your `TextConfig`.

### Basics

Markup uses XML-like tags. Tags must be properly closed/nested, or the layout
engine will return an error.

```okfmt
config := vglyph.TextConfig{
    style: vglyph.TextStyle{
        font_name: 'Sans 16',
    },
    use_markup: true
}

// Bold and Italic
app.ts.draw_text(10, 10, '<b>Bold</b> and <i>Italic</i>', config)!
```

### The `<span>` Tag

The `<span>` tag is the most powerful tool. It allows you to set specific
attributes for a range of text.

```okfmt
// Color and size
text := '<span foreground="blue" size="x-large">Blue Title</span>'

// Font weight and variant
text2 := '<span weight="bold" variant="small-caps">Small Caps Header</span>'

// Rise (Superscript-like effect)
text3 := '10<span size="small" rise="10000">th</span>'
```

### Full Attribute List

| Attribute | Description | Examples |
| :--- | :--- | :--- |
| `foreground` | Text color | `"#FF0000"`, `"blue"` |
| `background` | Background color | `"yellow"`, `"#333"` |
| `size` | Font size | `"small"`, `"x-large"`, `"12pt"` |
| `weight` | Font weight | `"light"`, `"bold"`, `"400"` |
| `rise` | Vertical align shift | `"5000"` (positive = up) |
| `underline` | Style of underline | `"single"`, `"double"`, `"none"` |
| `strikethrough` | Strikethrough | `"true"` |

---

## Font Management

### Loading Local Fonts

You can load `.ttf` or `.otf` files at runtime. This is critical for bundling
fonts with your game or app.

1. **Load the file**:
   ```okfmt
   // Call this once during init
   success := app.ts.add_font_file('assets/fonts/Inter-Regular.ttf')
   ```

2. **Reference by Name**:
   You do not use the filename to use the font. You must use the **Family Name**
   embedded in the font file.

   *Tip*: If you don't know the family name, open the font file in your OS font
   viewer.

   ```okfmt
   cfg := vglyph.TextConfig{
       style: vglyph.TextStyle{
           font_name: 'Inter 14' // "Inter" is the family name
       }
   }
   ```

### Icon Fonts

Icon fonts (like FontAwesome or Feather) work just like regular fonts.

1. Load the font: `app.ts.add_font_file('assets/feather.ttf')`
2. Use the Unicode Private Use Area (PUA) codepoints to display icons.

```okfmt
// Use \u escape sequence for the icon codepoint
icon_code := '\uF120'

app.ts.draw_text(x, y, icon_code, vglyph.TextConfig{
    style: vglyph.TextStyle{
        font_name: 'Feather 24'
    }
})
```

---

## Units and Measurements

### Points vs Pixels

In `vglyph` (and digital typography in general), it is important to distinguish
between **Points (pt)** and **Pixels (px)**.

- **Points**: Used for font sizes. One typographic point is defined as **1/72 of
  an inch**. When you specify a font size (e.g., in `font_name: 'Sans 12'` or
  `size: 12.0`), you are requesting a height of 12 points (approx. 1/6 inch).

- **Pixels**: Used for layout coordinates, widths, and positioning. In `vglyph`,
  these refer to **Logical Pixels**, not physical hardware pixels. A logical
  pixel is defined as **1/96 of an inch** (standard CSS reference pixel).

This distinction ensures that text appears at a consistent physical size across
different screens, regardless of the display's actual DPI (dots per inch).
Hardware scaling (e.g., Retina displays) handles the mapping of logical pixels
to physical device pixels automatically.

---


## Advanced Typography

### Tab Stops

By default, tab characters (`\t`) advance to the next 8-space multiple. You can
customize this behavior by providing a list of tab stops (in pixels) to create
perfectly aligned tables.

```okfmt
cfg := vglyph.TextConfig{
    style: vglyph.TextStyle{
        font_name: 'Mono 16'
    },
    // Align columns at 100px and 250px
    block: vglyph.BlockStyle{
        tabs: [100, 250]
    }
}

// "Name" starts at 0, "Age" aligns to 100px, "Role" aligns to 250px
header := 'Name\tAge\tRole'
data   := 'Alice\t28\tEngineer'
```

### OpenType Features

You can enable advanced OpenType features (like small caps, old-style numerals,
or stylistic sets) using the `opentype_features` map.

Common Features:
- `smcp`: Small Capitals
- `onum`: Old-style Numerals (text figures)
- `tnum`: Tabular Numerals (monospaced numbers, good for tables)
- `liga`: Standard Ligatures (usually on by default)
- `dlig`: Discretionary Ligatures

```okfmt
cfg := vglyph.TextConfig{
    style: vglyph.TextStyle{
        font_name: 'Serif 18',
        opentype_features: {
            'smcp': 1, // Enable small caps
            'onum': 1  // Enable old-style figures
        }
    }
}

app.ts.draw_text(x, y, 'The year is 2024', cfg)! 
// Displays "THE YEAR IS 2024" (in small caps) with old-style numbers.
```

---

## Performance Best Practices

### 1. Cache Your Layouts (Automatic)

Text shaping (calculating word wrap and glyph positions) is CPU intensive.

- **`TextSystem` users**: Caching is automatic. `draw_text` creates a hash of
  your text + config. If you draw the same string next frame, it hits the cache.
- **Dynamic Text**: If you have a counter that changes every frame (e.g.,
  `FPS: 60` -> `FPS: 61`), `TextSystem` will re-layout every time. This is
  usually fast enough for short strings, but avoid doing it for large paragraphs
  of changing text.

### 2. The `commit()` Cycle

GPU textures should not be updated multiple times per frame. `vglyph` queues
glyph uploads and performs them all at once when you call `commit()`.

**Rule**: Call `app.ts.commit()` exactly **once** at the end of your render
loop.

### 3. Glyph Atlas Size

The default atlas starts at 1024x1024 and **automatically resizes** if it fills
up. You generally do not need to manage this manually.

Exceptions where you might need `new_text_system_atlas_size`:
- **Massive Glyphs**: If a single glyph is larger than the default atlas size
  (e.g., > 1024px wide), you must initialize with a larger size.
