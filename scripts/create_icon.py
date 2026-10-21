"""Render the original geometric app mark; no third-party artwork."""
from pathlib import Path
from PIL import Image, ImageDraw

size = 1024
image = Image.new('RGB', (size, size), '#101117')
draw = ImageDraw.Draw(image)
def p(value): return round(value * size / 108)
draw.polygon([(p(x), p(y)) for x, y in [(23,23),(85,23),(85,37),(61,37),(61,85),(47,85),(47,37),(23,37)]], fill='#B7ACFF')
draw.polygon([(p(68),p(52)),(p(86),p(63)),(p(68),p(74))], fill='#F6A88A')
destination = Path(__file__).resolve().parents[1] / 'ios/TelaCut/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
image.save(destination)
print(destination)
