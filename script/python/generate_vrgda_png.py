#!/usr/bin/env python3
"""
Generate PNG chart of VRGDA curve using PIL/Pillow
Falls back to a simple bitmap approach if PIL is not available
"""

import csv
import os
import math

# Set the script directory as working directory
script_dir = os.path.dirname(os.path.abspath(__file__))
if script_dir:
    os.chdir(script_dir)

# Try to import PIL
try:
    from PIL import Image, ImageDraw, ImageFont
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

# Read the CSV data from parent directory
eth_amounts = []
love_multipliers = []

csv_path = os.path.join(os.path.dirname(script_dir), 'vrgda_curve_data.csv')
with open(csv_path, 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        eth_amounts.append(float(row['eth_amount']))
        love_multipliers.append(float(row['love_multiplier']))

if HAS_PIL:
    # Create PNG with PIL
    width, height = 800, 600
    margin = 60
    chart_width = width - 2 * margin
    chart_height = height - 2 * margin
    
    # Create image
    img = Image.new('RGB', (width, height), 'white')
    draw = ImageDraw.Draw(img)
    
    # Try to load a font, fall back to default if not available
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
        title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
        small_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 12)
    except:
        font = ImageFont.load_default()
        title_font = font
        small_font = font
    
    # Draw title
    draw.text((width // 2, 30), "Aminal VRGDA Love Curve", 
              font=title_font, anchor="mm", fill='black')
    
    # Draw chart border
    draw.rectangle([margin, margin, width - margin, height - margin], 
                   outline='black', width=2)
    
    # Draw zones
    zones = [
        (0.0001, 0.001, (255, 229, 229), 'Starving'),
        (0.001, 0.1, (255, 240, 229), 'Hungry'),
        (0.1, 1, (229, 245, 229), 'Fed'),
        (1, 10, (229, 229, 255), 'Well-Fed'),
        (10, 100, (240, 229, 255), 'Overfed'),
        (100, 200, (255, 229, 229), 'Extreme')
    ]
    
    for start, end, color, label in zones:
        x1 = margin + (math.log10(start) - math.log10(0.0001)) / (math.log10(200) - math.log10(0.0001)) * chart_width
        x2 = margin + (math.log10(end) - math.log10(0.0001)) / (math.log10(200) - math.log10(0.0001)) * chart_width
        draw.rectangle([x1, margin, x2, height - margin], fill=color)
    
    # Redraw chart border
    draw.rectangle([margin, margin, width - margin, height - margin], 
                   outline='black', width=2)
    
    # Draw grid lines and labels
    for i in range(11):
        y = margin + i * chart_height / 10
        draw.line([(margin, y), (width - margin, y)], fill='lightgray', width=1)
        mult = 10 - i
        draw.text((margin - 10, y), f"{mult}x", font=small_font, anchor="rm", fill='black')
    
    # X-axis labels
    x_labels = [0.0001, 0.001, 0.01, 0.1, 1, 10, 100]
    for eth in x_labels:
        x = margin + (math.log10(eth) - math.log10(0.0001)) / (math.log10(200) - math.log10(0.0001)) * chart_width
        draw.line([(x, margin), (x, height - margin)], fill='lightgray', width=1)
        draw.text((x, height - margin + 10), f"{eth}", font=small_font, anchor="mt", fill='black')
    
    # Draw the curve
    points = []
    for i, (eth, mult) in enumerate(zip(eth_amounts, love_multipliers)):
        x = margin + (math.log10(eth) - math.log10(0.0001)) / (math.log10(200) - math.log10(0.0001)) * chart_width
        y = margin + (10 - mult) * chart_height / 10
        points.append((x, y))
    
    # Draw line segments
    for i in range(len(points) - 1):
        draw.line([points[i], points[i + 1]], fill=(255, 107, 107), width=3)
    
    # Draw points
    for x, y in points:
        draw.ellipse([x - 3, y - 3, x + 3, y + 3], 
                     fill=(255, 107, 107), outline='darkred')
    
    # Draw threshold lines
    draw.line([(margin, margin), (width - margin, margin)], 
              fill='green', width=1)
    draw.text((width - margin + 5, margin), "Max (10x)", 
              font=small_font, anchor="lm", fill='green')
    
    y_eq = margin + chart_height * 0.45
    draw.line([(margin, y_eq), (width - margin, y_eq)], 
              fill='orange', width=1)
    draw.text((width - margin + 5, y_eq), "Equilibrium (~5.5x)", 
              font=small_font, anchor="lm", fill='orange')
    
    y_min = margin + chart_height * 0.99
    draw.line([(margin, y_min), (width - margin, y_min)], 
              fill='red', width=1)
    draw.text((width - margin + 5, y_min), "Min (0.1x)", 
              font=small_font, anchor="lm", fill='red')
    
    # Axis labels
    draw.text((width // 2, height - 10), "Energy Level (ETH)", 
              font=font, anchor="mm", fill='black')
    
    # Y-axis label (rotated - approximate with multiple characters)
    y_label = "Love Multiplier"
    for i, char in enumerate(y_label):
        draw.text((20, height // 2 - len(y_label) * 8 + i * 16), char, 
                  font=font, anchor="mm", fill='black')
    
    # Zone labels
    for start, end, color, label in zones:
        x_center = margin + ((math.log10(start) + math.log10(end)) / 2 - math.log10(0.0001)) / (math.log10(200) - math.log10(0.0001)) * chart_width
        if x_center > margin and x_center < width - margin:
            draw.text((x_center, margin - 10), label, 
                      font=small_font, anchor="mm", fill='black')
    
    # Save the image to output directory
    output_dir = os.path.join(os.path.dirname(script_dir), 'output')
    os.makedirs(output_dir, exist_ok=True)
    png_path = os.path.join(output_dir, 'vrgda_curve_chart.png')
    img.save(png_path, 'PNG', dpi=(300, 300))
    print(f"PNG chart saved to: {png_path}")
    
else:
    # Fallback: Generate a simple PPM file and convert to PNG
    print("PIL not available. Generating simple bitmap...")
    
    width, height = 800, 600
    margin = 60
    chart_width = width - 2 * margin
    chart_height = height - 2 * margin
    
    # Create pixel array
    pixels = [[(255, 255, 255) for _ in range(width)] for _ in range(height)]
    
    # Draw zones
    zones = [
        (0.0001, 0.001, (255, 229, 229)),
        (0.001, 0.1, (255, 240, 229)),
        (0.1, 1, (229, 245, 229)),
        (1, 10, (229, 229, 255)),
        (10, 100, (240, 229, 255)),
        (100, 200, (255, 229, 229))
    ]
    
    for start, end, color in zones:
        x1 = int(margin + (math.log10(start) - math.log10(0.0001)) / (math.log10(200) - math.log10(0.0001)) * chart_width)
        x2 = int(margin + (math.log10(end) - math.log10(0.0001)) / (math.log10(200) - math.log10(0.0001)) * chart_width)
        for y in range(margin, height - margin):
            for x in range(max(margin, x1), min(width - margin, x2)):
                pixels[y][x] = color
    
    # Draw border
    for x in range(margin, width - margin):
        pixels[margin][x] = (0, 0, 0)
        pixels[height - margin - 1][x] = (0, 0, 0)
    for y in range(margin, height - margin):
        pixels[y][margin] = (0, 0, 0)
        pixels[y][width - margin - 1] = (0, 0, 0)
    
    # Draw grid
    for i in range(11):
        y = margin + i * chart_height // 10
        for x in range(margin, width - margin):
            if x % 4 < 2:  # Dashed line
                pixels[y][x] = (200, 200, 200)
    
    # Draw curve
    prev_x, prev_y = None, None
    for i, (eth, mult) in enumerate(zip(eth_amounts, love_multipliers)):
        x = int(margin + (math.log10(eth) - math.log10(0.0001)) / (math.log10(200) - math.log10(0.0001)) * chart_width)
        y = int(margin + (10 - mult) * chart_height / 10)
        
        # Draw line from previous point
        if prev_x is not None:
            # Simple line drawing
            steps = max(abs(x - prev_x), abs(y - prev_y))
            if steps > 0:
                for j in range(steps + 1):
                    px = int(prev_x + (x - prev_x) * j / steps)
                    py = int(prev_y + (y - prev_y) * j / steps)
                    if 0 <= py < height and 0 <= px < width:
                        pixels[py][px] = (255, 107, 107)
                        # Make line thicker
                        if py > 0: pixels[py-1][px] = (255, 107, 107)
                        if py < height-1: pixels[py+1][px] = (255, 107, 107)
        
        # Draw point
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                if dx*dx + dy*dy <= 9:  # Circle
                    py, px = y + dy, x + dx
                    if 0 <= py < height and 0 <= px < width:
                        pixels[py][px] = (200, 50, 50)
        
        prev_x, prev_y = x, y
    
    # Save as PPM (simple format) to output directory
    output_dir = os.path.join(os.path.dirname(script_dir), 'output')
    os.makedirs(output_dir, exist_ok=True)
    ppm_path = os.path.join(output_dir, 'vrgda_curve_chart.ppm')
    with open(ppm_path, 'w') as f:
        f.write(f"P3\n{width} {height}\n255\n")
        for row in pixels:
            for r, g, b in row:
                f.write(f"{r} {g} {b} ")
            f.write("\n")
    
    print(f"PPM file saved to: {ppm_path}")
    
    # Try to convert PPM to PNG using available tools
    import subprocess
    import shutil
    
    converted = False
    
    # Try ImageMagick convert/magick
    if shutil.which('magick'):
        try:
            png_path = os.path.join(output_dir, 'vrgda_curve_chart.png')
            subprocess.run(['magick', ppm_path, png_path], check=True)
            converted = True
            print(f"PNG chart saved to: {png_path} (converted using ImageMagick)")
        except:
            pass
    elif shutil.which('convert'):
        try:
            png_path = os.path.join(output_dir, 'vrgda_curve_chart.png')
            subprocess.run(['convert', ppm_path, png_path], check=True)
            converted = True
            print(f"PNG chart saved to: {png_path} (converted using ImageMagick)")
        except:
            pass
    
    # Try macOS sips
    if not converted and shutil.which('sips'):
        try:
            png_path = os.path.join(output_dir, 'vrgda_curve_chart.png')
            subprocess.run(['sips', '-s', 'format', 'png', ppm_path, '--out', png_path], check=True)
            converted = True
            print(f"PNG chart saved to: {png_path} (converted using sips)")
        except:
            pass
    
    if converted:
        # Remove the PPM file
        try:
            os.remove(ppm_path)
        except:
            pass
    else:
        print("Note: Could not convert to PNG automatically. PPM file is available.")