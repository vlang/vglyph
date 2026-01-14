module vglyph

import gg

fn test_get_cache_key_consistency() {
	ts := TextSystem{
		ctx:      unsafe { nil }
		renderer: unsafe { nil }
	}

	cfg1 := TextConfig{
		style: TextStyle{
			font_name: 'Arial 12'
			color:     gg.black
		}
		block: BlockStyle{
			width: 100
			align: .left
		}
	}

	key1 := ts.get_cache_key('hello', cfg1)
	key2 := ts.get_cache_key('hello', cfg1)

	assert key1 != 0
	assert key1 == key2
}

fn test_get_cache_key_diff() {
	ts := TextSystem{
		ctx:      unsafe { nil }
		renderer: unsafe { nil }
	}

	cfg1 := TextConfig{
		style: TextStyle{
			font_name: 'Arial 12'
			color:     gg.black
		}
		block: BlockStyle{
			width: 100
			align: .left
		}
	}

	cfg2 := TextConfig{
		style: TextStyle{
			font_name: 'Arial 12'
			color:     gg.black
		}
		block: BlockStyle{
			width: 101 // changed
			align: .left
		}
	}

	key1 := ts.get_cache_key('hello', cfg1)
	key2 := ts.get_cache_key('hello', cfg2)

	assert key1 != key2
}

fn test_get_cache_key_diff_text() {
	ts := TextSystem{
		ctx:      unsafe { nil }
		renderer: unsafe { nil }
	}
	cfg1 := TextConfig{
		style: TextStyle{
			font_name: 'Arial 12'
		}
	}

	key1 := ts.get_cache_key('hello', cfg1)
	key2 := ts.get_cache_key('hello world', cfg1)

	assert key1 != key2
}
