#!/usr/bin/env node
/**
 * Generate NowPlaying for Plex app icons
 * Creates landscape (192×128 base size) icons in all required macOS sizes
 */

const { createCanvas } = require('canvas');
const fs = require('fs');
const path = require('path');

const colors = { orange: '#FF6B35', yellow: '#FFC93C', white: '#FFFFFF' };

function createGradient(ctx, x, y, width, height) {
    // Diagonal gradient from top-left to bottom-right
    const gradient = ctx.createLinearGradient(x, y, x + width, y + height);
    // More orange, less yellow: Orange dominant until 75%
    gradient.addColorStop(0, colors.orange);      // #FF6B35 Orange (top-left)
    gradient.addColorStop(0.75, '#FFAB3B');       // 50/50 blend (pushed way right)
    gradient.addColorStop(1, colors.yellow);      // #FFC93C Yellow (bottom-right corner only)
    return gradient;
}

function roundRect(ctx, x, y, width, height, radius) {
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.lineTo(x + width - radius, y);
    ctx.arcTo(x + width, y, x + width, y + radius, radius);
    ctx.lineTo(x + width, y + height - radius);
    ctx.arcTo(x + width, y + height, x + width - radius, y + height, radius);
    ctx.lineTo(x + radius, y + height);
    ctx.arcTo(x, y + height, x, y + height - radius, radius);
    ctx.lineTo(x, y + radius);
    ctx.arcTo(x, y, x + radius, y, radius);
    ctx.closePath();
}

function drawIcon(canvas, squareSize) {
    const ctx = canvas.getContext('2d');

    // Clear canvas with transparency
    ctx.clearRect(0, 0, squareSize, squareSize);

    // Calculate landscape dimensions maintaining 3:2 aspect ratio
    const landscapeHeight = squareSize * (2 / 3);
    const landscapeWidth = landscapeHeight * 1.5;

    // Center the landscape icon in the square
    const offsetX = (squareSize - landscapeWidth) / 2;
    const offsetY = (squareSize - landscapeHeight) / 2;

    // Save context for offset
    ctx.save();
    ctx.translate(offsetX, offsetY);

    const padding = Math.max(2, Math.min(landscapeWidth, landscapeHeight) * 0.08);
    const cornerRadius = Math.max(2, Math.min(landscapeWidth, landscapeHeight) * 0.08);

    // Draw gradient background (light version for app icon)
    const gradient = createGradient(ctx, padding, padding, landscapeWidth - padding * 2, landscapeHeight - padding * 2);
    ctx.fillStyle = gradient;
    roundRect(ctx, padding, padding, landscapeWidth - padding * 2, landscapeHeight - padding * 2, cornerRadius);
    ctx.fill();

    // Draw equalizer bars (solid white)
    const numBars = 7;
    const barAreaWidth = (landscapeWidth - padding * 2) * 0.6;
    const barAreaX = padding + (landscapeWidth - padding * 2 - barAreaWidth) / 2;
    const barSpacing = barAreaWidth / numBars;
    const barWidth = barSpacing * 0.5;
    const maxBarHeight = (landscapeHeight - padding * 2) * 0.6;
    const heights = [0.7, 0.9, 0.5, 0.8, 0.6, 0.85, 0.55];

    ctx.fillStyle = colors.white;
    for (let i = 0; i < numBars; i++) {
        const barHeight = maxBarHeight * heights[i % heights.length];
        const x = barAreaX + i * barSpacing;
        const y = padding + ((landscapeHeight - padding * 2) - barHeight) / 2;

        roundRect(ctx, x, y, barWidth, barHeight, barWidth / 4);
        ctx.fill();
    }

    // Draw chevron badge - white circle with orange chevron
    const badgeSize = Math.min(landscapeWidth, landscapeHeight) * 0.25;
    const badgeX = landscapeWidth - padding - badgeSize * 0.7;
    const badgeY = landscapeHeight - padding - badgeSize * 0.7;

    // Draw white circle
    ctx.fillStyle = colors.white;
    ctx.beginPath();
    ctx.arc(badgeX, badgeY, badgeSize * 0.5, 0, Math.PI * 2);
    ctx.fill();

    // Draw orange chevron inside circle
    const scale = badgeSize * 0.015;
    const chevronCenterX = 118.15;
    const chevronCenterY = 33.85;

    ctx.save();
    ctx.translate(badgeX, badgeY);
    ctx.scale(scale, scale);
    ctx.translate(-chevronCenterX + 1, -chevronCenterY);

    ctx.fillStyle = colors.orange;
    ctx.beginPath();
    ctx.moveTo(117.9, 33.9);
    ctx.lineTo(104.1, 13.5);
    ctx.lineTo(118.3, 13.5);
    ctx.lineTo(132.0, 33.9);
    ctx.lineTo(118.3, 54.2);
    ctx.lineTo(104.1, 54.2);
    ctx.closePath();
    ctx.fill();

    ctx.restore();

    // Restore context after landscape drawing
    ctx.restore();
}

function drawDriveIcon(canvas, size) {
    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, size, size);

    // Calculate landscape dimensions maintaining 3:2 aspect ratio
    const landscapeHeight = size * (2 / 3);
    const landscapeWidth = landscapeHeight * 1.5;

    // Center the landscape icon in the square
    const offsetX = (size - landscapeWidth) / 2;
    const offsetY = (size - landscapeHeight) / 2;

    // Save context for offset
    ctx.save();
    ctx.translate(offsetX, offsetY);

    const padding = Math.max(2, Math.min(landscapeWidth, landscapeHeight) * 0.08);
    const cornerRadius = Math.max(2, Math.min(landscapeWidth, landscapeHeight) * 0.08);

    // INVERTED APPROACH: Start with transparent background, draw white elements
    // The background stays transparent so the DMG gradient shows through
    // Only the bars and badge are white, creating the "cutout" effect

    // Draw equalizer bars as WHITE (will appear as white against gradient)
    const numBars = 7;
    const barAreaWidth = (landscapeWidth - padding * 2) * 0.6;
    const barAreaX = padding + (landscapeWidth - padding * 2 - barAreaWidth) / 2;
    const barSpacing = barAreaWidth / numBars;
    const barWidth = barSpacing * 0.5;
    const maxBarHeight = (landscapeHeight - padding * 2) * 0.6;
    const heights = [0.7, 0.9, 0.5, 0.8, 0.6, 0.85, 0.55];

    // Draw solid white bars (fully opaque for clarity)
    ctx.fillStyle = 'rgba(255, 255, 255, 1.0)';
    for (let i = 0; i < numBars; i++) {
        const barHeight = maxBarHeight * heights[i % heights.length];
        const x = barAreaX + i * barSpacing;
        const y = padding + ((landscapeHeight - padding * 2) - barHeight) / 2;

        roundRect(ctx, x, y, barWidth, barHeight, barWidth / 4);
        ctx.fill();
    }

    // Draw chevron badge - white circle with transparent center, then white chevron inside
    const badgeSize = Math.min(landscapeWidth, landscapeHeight) * 0.25;
    const badgeX = landscapeWidth - padding - badgeSize * 0.7;
    const badgeY = landscapeHeight - padding - badgeSize * 0.7;

    // Draw white circle (fully opaque for clarity)
    ctx.fillStyle = 'rgba(255, 255, 255, 1.0)';
    ctx.beginPath();
    ctx.arc(badgeX, badgeY, badgeSize * 0.5, 0, Math.PI * 2);
    ctx.fill();

    // Cut out the center of the circle to let gradient show through
    ctx.globalCompositeOperation = 'destination-out';
    ctx.fillStyle = 'rgba(0, 0, 0, 1)';
    ctx.beginPath();
    ctx.arc(badgeX, badgeY, badgeSize * 0.42, 0, Math.PI * 2); // Slightly smaller to create border
    ctx.fill();

    // Reset and draw white chevron inside the transparent circle
    ctx.globalCompositeOperation = 'source-over';

    const scale = badgeSize * 0.015;
    const chevronCenterX = 118.15;
    const chevronCenterY = 33.85;

    ctx.save();
    ctx.translate(badgeX, badgeY);
    ctx.scale(scale, scale);
    ctx.translate(-chevronCenterX + 1, -chevronCenterY);

    ctx.fillStyle = 'rgba(255, 255, 255, 1.0)';
    ctx.beginPath();
    ctx.moveTo(117.9, 33.9);
    ctx.lineTo(104.1, 13.5);
    ctx.lineTo(118.3, 13.5);
    ctx.lineTo(132.0, 33.9);
    ctx.lineTo(118.3, 54.2);
    ctx.lineTo(104.1, 54.2);
    ctx.closePath();
    ctx.fill();

    ctx.restore();

    // Restore context after landscape drawing
    ctx.restore();
}

// macOS requires these specific sizes for AppIcon.appiconset
// Using square format with landscape logo centered inside
const sizes = [
    { name: 'icon_16x16', size: 16 },        // 16pt @1x
    { name: 'icon_16x16@2x', size: 32 },     // 16pt @2x
    { name: 'icon_32x32', size: 32 },        // 32pt @1x
    { name: 'icon_32x32@2x', size: 64 },     // 32pt @2x
    { name: 'icon_128x128', size: 128 },     // 128pt @1x
    { name: 'icon_128x128@2x', size: 256 },  // 128pt @2x
    { name: 'icon_256x256', size: 256 },     // 256pt @1x
    { name: 'icon_256x256@2x', size: 512 },  // 256pt @2x
    { name: 'icon_512x512', size: 512 },     // 512pt @1x
    { name: 'icon_512x512@2x', size: 1024 }  // 512pt @2x
];

const outputDir = path.join(__dirname, 'PlexWidget', 'PlexWidget', 'Assets.xcassets', 'AppIcon.appiconset');

console.log('Generating NowPlaying for Plex icons...\n');

sizes.forEach(({ name, size }) => {
    console.log(`Creating ${name}.png (${size}×${size})`);

    const canvas = createCanvas(size, size);
    drawIcon(canvas, size);

    const buffer = canvas.toBuffer('image/png');
    const outputPath = path.join(outputDir, `${name}.png`);
    fs.writeFileSync(outputPath, buffer);
});

console.log('\n✅ All icon sizes generated successfully!');
console.log(`📁 Output directory: ${outputDir}`);

// Generate DMG volume icon (3D drive with logo)
console.log('\n🔨 Generating DMG volume icon...\n');
const dmgSizes = [
    { name: 'dmg-icon_16x16', size: 16 },
    { name: 'dmg-icon_32x32', size: 32 },
    { name: 'dmg-icon_128x128', size: 128 },
    { name: 'dmg-icon_256x256', size: 256 },
    { name: 'dmg-icon_512x512', size: 512 },
];

const dmgOutputDir = path.join(__dirname, 'PlexWidget');

dmgSizes.forEach(({ name, size }) => {
    console.log(`Creating ${name}.png (${size}×${size})`);

    const canvas = createCanvas(size, size);
    drawDriveIcon(canvas, size);

    const buffer = canvas.toBuffer('image/png');
    const outputPath = path.join(dmgOutputDir, `${name}.png`);
    fs.writeFileSync(outputPath, buffer);
});

console.log('\n✅ DMG icon PNGs generated!');
console.log(`📁 DMG icons: ${dmgOutputDir}/dmg-icon_*.png`);
console.log('\n🔧 Now converting to .icns format...');

// Convert PNGs to .icns using iconutil
const { execSync } = require('child_process');
const iconsetDir = path.join(__dirname, 'PlexWidget', 'dmg-icon.iconset');
const icnsOutput = path.join(__dirname, 'PlexWidget', 'dmg-volume-icon.icns');

// Create iconset directory
if (fs.existsSync(iconsetDir)) {
    fs.rmSync(iconsetDir, { recursive: true });
}
fs.mkdirSync(iconsetDir);

// Copy PNGs to iconset with proper naming convention
// iconutil requires specific filenames
fs.copyFileSync(
    path.join(dmgOutputDir, 'dmg-icon_16x16.png'),
    path.join(iconsetDir, 'icon_16x16.png')
);
fs.copyFileSync(
    path.join(dmgOutputDir, 'dmg-icon_32x32.png'),
    path.join(iconsetDir, 'icon_16x16@2x.png')
);
fs.copyFileSync(
    path.join(dmgOutputDir, 'dmg-icon_32x32.png'),
    path.join(iconsetDir, 'icon_32x32.png')
);
fs.copyFileSync(
    path.join(dmgOutputDir, 'dmg-icon_128x128.png'),
    path.join(iconsetDir, 'icon_128x128.png')
);
fs.copyFileSync(
    path.join(dmgOutputDir, 'dmg-icon_256x256.png'),
    path.join(iconsetDir, 'icon_128x128@2x.png')
);
fs.copyFileSync(
    path.join(dmgOutputDir, 'dmg-icon_256x256.png'),
    path.join(iconsetDir, 'icon_256x256.png')
);
fs.copyFileSync(
    path.join(dmgOutputDir, 'dmg-icon_512x512.png'),
    path.join(iconsetDir, 'icon_256x256@2x.png')
);
fs.copyFileSync(
    path.join(dmgOutputDir, 'dmg-icon_512x512.png'),
    path.join(iconsetDir, 'icon_512x512.png')
);

// Convert iconset to icns
console.log('Running iconutil to create .icns file...');
execSync(`iconutil -c icns "${iconsetDir}" -o "${icnsOutput}"`);

// Clean up iconset directory
fs.rmSync(iconsetDir, { recursive: true });

console.log('✅ DMG volume icon created: dmg-volume-icon.icns');
console.log('\n🎉 All icons generated successfully!');
