#!/usr/bin/env python3
"""
Generate SVG chart of VRGDA curve without external dependencies
"""

import csv
import os
import math

# Set the script directory as working directory
script_dir = os.path.dirname(os.path.abspath(__file__))
if script_dir:
    os.chdir(script_dir)

# Read the CSV data from parent directory
eth_amounts = []
love_multipliers = []

csv_path = os.path.join(os.path.dirname(script_dir), 'vrgda_curve_data.csv')
with open(csv_path, 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        eth_amounts.append(float(row['eth_amount']))
        love_multipliers.append(float(row['love_multiplier']))

# SVG dimensions
width = 800
height = 600
margin = 60
chart_width = width - 2 * margin
chart_height = height - 2 * margin

# Create SVG
svg = f'''<svg width="{width}" height="{height}" xmlns="http://www.w3.org/2000/svg">
  <rect width="{width}" height="{height}" fill="white"/>
  
  <!-- Title -->
  <text x="{width/2}" y="30" text-anchor="middle" font-size="24" font-weight="bold">Aminal VRGDA Love Curve</text>
  
  <!-- Chart area -->
  <rect x="{margin}" y="{margin}" width="{chart_width}" height="{chart_height}" 
        fill="none" stroke="black" stroke-width="2"/>
'''

# Add zone backgrounds
zones = [
    (0.0001, 0.001, '#FFE5E5', 'Starving'),
    (0.001, 0.1, '#FFF0E5', 'Hungry'),
    (0.1, 1, '#E5F5E5', 'Fed'),
    (1, 10, '#E5E5FF', 'Well-Fed'),
    (10, 100, '#F0E5FF', 'Overfed'),
    (100, 200, '#FFE5E5', 'Extreme')
]

for start, end, color, label in zones:
    # Convert to log scale positions
    x1 = margin + (math.log10(start) - math.log10(0.0001)) / (math.log10(200) - math.log10(0.0001)) * chart_width
    x2 = margin + (math.log10(end) - math.log10(0.0001)) / (math.log10(200) - math.log10(0.0001)) * chart_width
    
    svg += f'''  <rect x="{x1}" y="{margin}" width="{x2-x1}" height="{chart_height}" 
        fill="{color}" opacity="0.2"/>
'''

# Add grid lines
for i in range(11):
    y = margin + i * chart_height / 10
    svg += f'  <line x1="{margin}" y1="{y}" x2="{margin + chart_width}" y2="{y}" stroke="#ddd" stroke-dasharray="2,2"/>\n'
    # Y-axis labels
    mult = 10 - i
    svg += f'  <text x="{margin - 10}" y="{y + 5}" text-anchor="end" font-size="12">{mult}x</text>\n'

# X-axis log scale labels
x_labels = [0.0001, 0.001, 0.01, 0.1, 1, 10, 100]
for eth in x_labels:
    x = margin + (math.log10(eth) - math.log10(0.0001)) / (math.log10(200) - math.log10(0.0001)) * chart_width
    svg += f'  <line x1="{x}" y1="{margin}" x2="{x}" y2="{margin + chart_height}" stroke="#ddd" stroke-dasharray="2,2"/>\n'
    svg += f'  <text x="{x}" y="{margin + chart_height + 20}" text-anchor="middle" font-size="12">{eth}</text>\n'

# Plot the curve
points = []
for i, (eth, mult) in enumerate(zip(eth_amounts, love_multipliers)):
    x = margin + (math.log10(eth) - math.log10(0.0001)) / (math.log10(200) - math.log10(0.0001)) * chart_width
    y = margin + (10 - mult) * chart_height / 10
    points.append(f"{x},{y}")

# Draw the curve
svg += f'  <polyline points="{" ".join(points)}" fill="none" stroke="#FF6B6B" stroke-width="3"/>\n'

# Add data points
for i, (eth, mult) in enumerate(zip(eth_amounts, love_multipliers)):
    x = margin + (math.log10(eth) - math.log10(0.0001)) / (math.log10(200) - math.log10(0.0001)) * chart_width
    y = margin + (10 - mult) * chart_height / 10
    svg += f'  <circle cx="{x}" cy="{y}" r="3" fill="#FF6B6B" stroke="darkred" stroke-width="1"/>\n'

# Add key threshold lines
svg += f'''
  <!-- Threshold lines -->
  <line x1="{margin}" y1="{margin}" x2="{margin + chart_width}" y2="{margin}" 
        stroke="green" stroke-dasharray="5,5" opacity="0.5"/>
  <text x="{margin + chart_width + 10}" y="{margin + 5}" font-size="12" fill="green">Max (10x)</text>
  
  <line x1="{margin}" y1="{margin + chart_height * 0.45}" x2="{margin + chart_width}" y2="{margin + chart_height * 0.45}" 
        stroke="orange" stroke-dasharray="5,5" opacity="0.5"/>
  <text x="{margin + chart_width + 10}" y="{margin + chart_height * 0.45 + 5}" font-size="12" fill="orange">Equilibrium (~5.5x)</text>
  
  <line x1="{margin}" y1="{margin + chart_height * 0.99}" x2="{margin + chart_width}" y2="{margin + chart_height * 0.99}" 
        stroke="red" stroke-dasharray="5,5" opacity="0.5"/>
  <text x="{margin + chart_width + 10}" y="{margin + chart_height * 0.99 + 5}" font-size="12" fill="red">Min (0.1x)</text>
'''

# Add axis labels
svg += f'''
  <!-- Axis labels -->
  <text x="{width/2}" y="{height - 10}" text-anchor="middle" font-size="14" font-weight="bold">Energy Level (ETH)</text>
  <text x="20" y="{height/2}" text-anchor="middle" font-size="14" font-weight="bold" transform="rotate(-90 20 {height/2})">Love Multiplier</text>
'''

# Add zone labels
for start, end, color, label in zones:
    x_center = margin + ((math.log10(start) + math.log10(end)) / 2 - math.log10(0.0001)) / (math.log10(200) - math.log10(0.0001)) * chart_width
    svg += f'  <text x="{x_center}" y="{margin - 10}" text-anchor="middle" font-size="12" font-weight="bold">{label}</text>\n'

svg += '</svg>'

# Save the SVG file to output directory
output_dir = os.path.join(os.path.dirname(script_dir), 'output')
os.makedirs(output_dir, exist_ok=True)
svg_path = os.path.join(output_dir, 'vrgda_curve_chart.svg')
with open(svg_path, 'w') as f:
    f.write(svg)

print(f"SVG chart saved to: {svg_path}")

# Also create an HTML file to view it
html = f'''<!DOCTYPE html>
<html>
<head>
    <title>Aminal VRGDA Love Curve</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            max-width: 1000px;
            margin: 0 auto;
            padding: 20px;
        }}
        .chart-container {{
            background: white;
            border: 1px solid #ddd;
            padding: 20px;
            margin: 20px 0;
        }}
        .summary {{
            background: #f5f5f5;
            padding: 20px;
            border-radius: 8px;
        }}
        table {{
            border-collapse: collapse;
            width: 100%;
            margin: 20px 0;
        }}
        th, td {{
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }}
        th {{
            background: #f0f0f0;
        }}
    </style>
</head>
<body>
    <h1>Aminal VRGDA Love Curve</h1>
    
    <div class="chart-container">
        {svg}
    </div>
    
    <div class="summary">
        <h2>Summary</h2>
        <p>The VRGDA (Variable Rate Gradual Dutch Auction) creates a smooth curve that incentivizes feeding hungry Aminals while discouraging overfeeding.</p>
        
        <table>
            <tr>
                <th>Energy Level</th>
                <th>Love Multiplier</th>
                <th>Zone</th>
                <th>Incentive</th>
            </tr>
            <tr>
                <td>&lt;0.005 ETH</td>
                <td>10x</td>
                <td>Starving</td>
                <td>Maximum reward for rescuing neglected Aminals</td>
            </tr>
            <tr>
                <td>0.005-0.1 ETH</td>
                <td>9.5x-7.4x</td>
                <td>Hungry</td>
                <td>Strong incentive to feed low-energy Aminals</td>
            </tr>
            <tr>
                <td>0.1-1 ETH</td>
                <td>7.4x-5.5x</td>
                <td>Fed</td>
                <td>Good returns encourage regular interaction</td>
            </tr>
            <tr>
                <td>1-10 ETH</td>
                <td>5.5x-3.5x</td>
                <td>Well-Fed</td>
                <td>Natural equilibrium zone</td>
            </tr>
            <tr>
                <td>10-100 ETH</td>
                <td>3.5x-0.1x</td>
                <td>Overfed</td>
                <td>Diminishing returns discourage overfeeding</td>
            </tr>
            <tr>
                <td>&gt;100 ETH</td>
                <td>0.1x</td>
                <td>Extreme</td>
                <td>Severe penalty prevents wasteful feeding</td>
            </tr>
        </table>
    </div>
</body>
</html>'''

html_path = os.path.join(output_dir, 'vrgda_curve_chart.html')
with open(html_path, 'w') as f:
    f.write(html)

print(f"HTML chart saved to: {html_path}")
print("\nYou can open the HTML file in a web browser to view the interactive chart.")