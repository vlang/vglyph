#!/bin/bash
mkdir -p assets/fonts
rm -f assets/fonts/*

echo "Downloading Noto Sans (Static)..."
# Using hinted/ttf static version
curl -L -o assets/fonts/NotoSans-Regular.ttf https://raw.githubusercontent.com/notofonts/noto-fonts/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf

echo "Downloading Noto Sans Arabic (Static)..."
curl -L -o assets/fonts/NotoSansArabic-Regular.ttf https://raw.githubusercontent.com/notofonts/noto-fonts/main/hinted/ttf/NotoSansArabic/NotoSansArabic-Regular.ttf

echo "Downloading Noto Sans JP (Static)..."
# Using OTF static version for CJK
curl -L -o assets/fonts/NotoSansCJKjp-Regular.otf https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf

echo "Downloading Noto Color Emoji..."
curl -L -o assets/fonts/NotoColorEmoji.ttf https://raw.githubusercontent.com/googlefonts/noto-emoji/main/fonts/NotoColorEmoji.ttf

echo "Fonts downloaded to assets/fonts/"
ls -l assets/fonts/
