#!/usr/bin/env python3
"""
Simple VRGDA curve visualization using ASCII art
Reads CSV data and creates a text-based chart
"""

import csv
import os
import math

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

# Create ASCII chart
print("\n" + "="*80)
print(" "*25 + "AMINAL VRGDA LOVE CURVE")
print("="*80)
print("\nLove Multiplier vs Energy Level (ETH)")
print("\n10x |" + "*" * 70)

# Create the chart rows
chart_height = 20
chart_width = 70

for row in range(chart_height):
    # Calculate the multiplier for this row (from 10 down to 0)
    row_multiplier = 10 - (row * 0.5)
    
    # Print the y-axis label
    if row_multiplier == int(row_multiplier):
        label = f"{int(row_multiplier)}x"
    else:
        label = f"{row_multiplier:.1f}x"
    
    print(f"{label:>4} |", end="")
    
    # Plot points for this row
    for col in range(chart_width):
        # Map column to ETH amount (log scale)
        eth_position = 0.0001 * math.pow(2000000, col / chart_width)
        
        # Find the closest data point
        closest_idx = 0
        min_diff = float('inf')
        for i, eth in enumerate(eth_amounts):
            if abs(math.log(eth) - math.log(eth_position)) < min_diff:
                min_diff = abs(math.log(eth) - math.log(eth_position))
                closest_idx = i
        
        # Check if this position should have a point
        if abs(love_multipliers[closest_idx] - row_multiplier) < 0.25:
            print("█", end="")
        elif abs(love_multipliers[closest_idx] - row_multiplier) < 0.5:
            print("▄", end="")
        else:
            print(" ", end="")
    
    print()

# X-axis
print(" 0x |" + "─" * chart_width)
print("     0.0001 ETH" + " " * 20 + "1 ETH" + " " * 20 + "100 ETH →")

# Summary statistics
print("\n" + "="*80)
print("SUMMARY STATISTICS:")
print("="*80)
print(f"Energy Range: {min(eth_amounts):.4f} - {max(eth_amounts):.0f} ETH")
print(f"Multiplier Range: {min(love_multipliers):.1f}x - {max(love_multipliers):.1f}x")

# Key thresholds
print("\nKEY THRESHOLDS:")
print("-" * 40)
print("Energy Level | Love Multiplier | Zone")
print("-" * 40)

zones = [
    (0.001, "Starving"),
    (0.01, "Hungry"),
    (0.1, "Hungry"),
    (1, "Fed"),
    (10, "Well-Fed"),
    (50, "Overfed"),
    (100, "Extremely Overfed")
]

for eth_target, zone in zones:
    # Find closest actual value
    closest_mult = 0
    for i, eth in enumerate(eth_amounts):
        if abs(eth - eth_target) < 0.01 or (eth_target >= 1 and abs(eth - eth_target) < eth_target * 0.1):
            closest_mult = love_multipliers[i]
            break
    
    print(f"{eth_target:>8.3f} ETH | {closest_mult:>14.1f}x | {zone}")

print("-" * 40)

# Save a simple summary file
with open('vrgda_curve_summary.txt', 'w') as f:
    f.write("AMINAL VRGDA CURVE SUMMARY\n")
    f.write("=" * 50 + "\n\n")
    f.write(f"Energy Range: {min(eth_amounts):.4f} - {max(eth_amounts):.0f} ETH\n")
    f.write(f"Multiplier Range: {min(love_multipliers):.1f}x - {max(love_multipliers):.1f}x\n\n")
    f.write("Key Points:\n")
    f.write("- Starving (<0.005 ETH): 10x multiplier\n")
    f.write("- Hungry (0.005-0.1 ETH): 9.5x-7.4x multiplier\n")
    f.write("- Fed (0.1-1 ETH): 7.4x-5.5x multiplier\n")
    f.write("- Well-Fed (1-10 ETH): 5.5x-3.5x multiplier\n")
    f.write("- Overfed (10-100 ETH): 3.5x-0.1x multiplier\n")
    f.write("- Beyond Threshold (>100 ETH): 0.1x multiplier\n")

print("\nSummary saved to: vrgda_curve_summary.txt")