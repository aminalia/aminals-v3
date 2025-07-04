#!/usr/bin/env python3
"""
Plot VRGDA curve data from CSV file
Generates a chart showing love multiplier vs energy level
"""

import matplotlib.pyplot as plt
import numpy as np
import csv
import os

# Set the script directory as working directory
script_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(script_dir)

# Read the CSV data
eth_amounts = []
love_multipliers = []

with open('vrgda_curve_data.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        eth_amounts.append(float(row['eth_amount']))
        love_multipliers.append(float(row['love_multiplier']))

# Create the plot
fig, ax = plt.subplots(figsize=(12, 8))

# Plot the love multiplier curve
ax.plot(eth_amounts, love_multipliers, 
        linewidth=2.5, color='#FF6B6B', marker='o', markersize=4, 
        markeredgecolor='darkred', markeredgewidth=0.5)

# Set up the axes
ax.set_xlabel('Energy Level (ETH)', fontsize=12, fontweight='bold')
ax.set_ylabel('Love Multiplier', fontsize=12, fontweight='bold')
ax.set_title('Aminal VRGDA Love Curve', fontsize=16, fontweight='bold', pad=20)

# Use log scale for x-axis to better show the full range
ax.set_xscale('log')
ax.set_xlim(0.0001, 200)
ax.set_ylim(0, 11)

# Add grid
ax.grid(True, alpha=0.3, linestyle='--')

# Add horizontal lines for key thresholds
ax.axhline(y=10, color='green', linestyle=':', alpha=0.5, label='Max multiplier (10x)')
ax.axhline(y=5.5, color='orange', linestyle=':', alpha=0.5, label='Equilibrium (~5.5x)')
ax.axhline(y=0.1, color='red', linestyle=':', alpha=0.5, label='Min multiplier (0.1x)')

# Add vertical lines for energy zones
zones = [
    (0.001, 'Starving', '#FFE5E5'),
    (0.1, 'Hungry', '#FFF0E5'),
    (1, 'Fed', '#E5F5E5'),
    (10, 'Well-Fed', '#E5E5FF'),
    (100, 'Overfed', '#F0E5FF')
]

# Shade the zones
prev_x = 0.0001
for x, label, color in zones:
    ax.axvspan(prev_x, x, alpha=0.15, color=color)
    # Add zone labels at the top
    if prev_x < 1:
        label_x = np.sqrt(prev_x * x)  # Geometric mean for log scale
    else:
        label_x = (prev_x + x) / 2
    ax.text(label_x, 10.5, label, ha='center', va='bottom', 
            fontsize=10, fontweight='bold', color='#333')
    prev_x = x

# Shade the extreme zone
ax.axvspan(100, 200, alpha=0.2, color='#FFE5E5')
ax.text(140, 10.5, 'Extreme', ha='center', va='bottom', 
        fontsize=10, fontweight='bold', color='#333')

# Add specific point annotations
key_points = [
    (0.001, 10, "10x"),
    (0.1, 7.38, "7.4x"),
    (1, 5.46, "5.5x"),
    (10, 3.48, "3.5x"),
    (50, 2.34, "2.3x"),
    (100, 0.1, "0.1x")
]

for x, y_target, label in key_points:
    # Find the closest actual y value in the data
    min_diff = float('inf')
    actual_y = y_target
    for i, eth in enumerate(eth_amounts):
        if abs(eth - x) < min_diff:
            min_diff = abs(eth - x)
            actual_y = love_multipliers[i]
    
    ax.annotate(label, xy=(x, actual_y), xytext=(x, actual_y + 0.5),
                fontsize=9, ha='center', fontweight='bold',
                bbox=dict(boxstyle='round,pad=0.3', facecolor='white', 
                         edgecolor='gray', alpha=0.8))

# Add legend
ax.legend(loc='upper right', framealpha=0.9)

# Format the plot
plt.tight_layout()

# Save the plot
output_path = 'vrgda_curve_chart.png'
plt.savefig(output_path, dpi=300, bbox_inches='tight')
print(f"Chart saved to: {output_path}")

# Also save as PDF for higher quality
pdf_path = 'vrgda_curve_chart.pdf'
plt.savefig(pdf_path, bbox_inches='tight')
print(f"PDF version saved to: {pdf_path}")

# Display summary statistics
print("\nVRGDA Curve Summary:")
print(f"Minimum ETH: {min(eth_amounts):.4f}")
print(f"Maximum ETH: {max(eth_amounts):.0f}")
print(f"Maximum multiplier: {max(love_multipliers):.1f}x")
print(f"Minimum multiplier: {min(love_multipliers):.1f}x")

# Find the ETH amount where multiplier drops below 5x
for i, mult in enumerate(love_multipliers):
    if mult < 5:
        print(f"Multiplier drops below 5x at: {eth_amounts[i]:.1f} ETH")
        break

# Find the ETH amount where multiplier drops below 1x
for i, mult in enumerate(love_multipliers):
    if mult < 1:
        print(f"Multiplier drops below 1x at: {eth_amounts[i]:.1f} ETH")
        break