import os
from PIL import Image, ImageFilter, ImageOps, ImageDraw
import numpy as np

def generate_icons():
    src_path = 'icon image.jpeg'
    src = Image.open(src_path).convert('RGB')
    
    # 1. Precise content box
    # Left: 19, Top: 37, Right: 213, Bottom: 201
    crop = src.crop((19, 37, 214, 202)) # 195 x 165
    
    # 2. Extract transparency: pure white becomes alpha 0, colored letters have alpha 255
    arr = np.array(crop).astype(float)
    dist_to_white = np.sqrt((255 - arr[:,:,0])**2 + (255 - arr[:,:,1])**2 + (255 - arr[:,:,2])**2)
    
    # Smooth alpha mask
    alpha = np.clip((dist_to_white - 8.0) / 20.0, 0.0, 1.0) * 255.0
    
    # Clamp near-white RGB to pure 255
    arr[dist_to_white < 15] = [255, 255, 255]
    
    rgba_arr = np.zeros((crop.height, crop.width, 4), dtype=np.uint8)
    rgba_arr[:, :, :3] = np.clip(arr, 0, 255).astype(np.uint8)
    rgba_arr[:, :, 3] = alpha.astype(np.uint8)
    
    clean_logo_trans = Image.fromarray(rgba_arr, mode='RGBA')
    
    # Also clean RGB logo on white
    clean_logo_white = Image.new('RGB', clean_logo_trans.size, (255, 255, 255))
    clean_logo_white.paste(clean_logo_trans, mask=clean_logo_trans.split()[3])
    
    res_dir = os.path.join('android', 'app', 'src', 'main', 'res')
    
    # Density definitions: (folder, legacy_size, adaptive_size)
    densities = [
        ('mipmap-mdpi', 48, 108),
        ('mipmap-hdpi', 72, 162),
        ('mipmap-xhdpi', 96, 216),
        ('mipmap-xxhdpi', 144, 324),
        ('mipmap-xxxhdpi', 192, 432),
    ]
    
    for folder, leg_sz, adp_sz in densities:
        folder_path = os.path.join(res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        # A. Adaptive Foreground (transparent background, logo in safe zone ~65% of adp_sz)
        fg = Image.new('RGBA', (adp_sz, adp_sz), (0, 0, 0, 0))
        target_w = int(adp_sz * 0.62)
        target_h = int(clean_logo_trans.height * (target_w / clean_logo_trans.width))
        resized_logo_trans = clean_logo_trans.resize((target_w, target_h), Image.Resampling.LANCZOS)
        # Subtle sharpening
        resized_logo_trans = resized_logo_trans.filter(ImageFilter.UnsharpMask(radius=1.2, percent=110, threshold=1))
        
        paste_x = (adp_sz - target_w) // 2
        paste_y = (adp_sz - target_h) // 2
        fg.paste(resized_logo_trans, (paste_x, paste_y), mask=resized_logo_trans.split()[3])
        fg.save(os.path.join(folder_path, 'ic_launcher_foreground.png'), 'PNG')
        
        # B. Legacy Icon (white squircle / rounded rect, logo ~70% of leg_sz)
        leg_icon = Image.new('RGBA', (leg_sz, leg_sz), (0, 0, 0, 0))
        # Draw rounded rectangle in white
        draw = ImageDraw.Draw(leg_icon)
        corner_rad = max(4, int(leg_sz * 0.20)) # modern 20% squircle curve
        draw.rounded_rectangle([(0, 0), (leg_sz - 1, leg_sz - 1)], radius=corner_rad, fill=(255, 255, 255, 255))
        
        leg_w = int(leg_sz * 0.72)
        leg_h = int(clean_logo_trans.height * (leg_w / clean_logo_trans.width))
        resized_leg_logo = clean_logo_trans.resize((leg_w, leg_h), Image.Resampling.LANCZOS)
        resized_leg_logo = resized_leg_logo.filter(ImageFilter.UnsharpMask(radius=1.0, percent=110, threshold=1))
        
        px = (leg_sz - leg_w) // 2
        py = (leg_sz - leg_h) // 2
        leg_icon.paste(resized_leg_logo, (px, py), mask=resized_leg_logo.split()[3])
        leg_icon.save(os.path.join(folder_path, 'ic_launcher.png'), 'PNG')
        
        # C. Round Icon (circle masked white background)
        round_icon = Image.new('RGBA', (leg_sz, leg_sz), (0, 0, 0, 0))
        draw_round = ImageDraw.Draw(round_icon)
        draw_round.ellipse([(0, 0), (leg_sz - 1, leg_sz - 1)], fill=(255, 255, 255, 255))
        
        rnd_w = int(leg_sz * 0.65)
        rnd_h = int(clean_logo_trans.height * (rnd_w / clean_logo_trans.width))
        resized_rnd_logo = clean_logo_trans.resize((rnd_w, rnd_h), Image.Resampling.LANCZOS)
        resized_rnd_logo = resized_rnd_logo.filter(ImageFilter.UnsharpMask(radius=1.0, percent=110, threshold=1))
        
        rpx = (leg_sz - rnd_w) // 2
        rpy = (leg_sz - rnd_h) // 2
        round_icon.paste(resized_rnd_logo, (rpx, rpy), mask=resized_rnd_logo.split()[3])
        round_icon.save(os.path.join(folder_path, 'ic_launcher_round.png'), 'PNG')
        
    # Also create master 512x512 app_icon.png for assets and res/drawable
    master_512 = Image.new('RGBA', (512, 512), (255, 255, 255, 255))
    mw = int(512 * 0.72)
    mh = int(clean_logo_trans.height * (mw / clean_logo_trans.width))
    resized_master = clean_logo_trans.resize((mw, mh), Image.Resampling.LANCZOS)
    resized_master = resized_master.filter(ImageFilter.UnsharpMask(radius=1.2, percent=110, threshold=1))
    master_512.paste(resized_master, ((512 - mw) // 2, (512 - mh) // 2), mask=resized_master.split()[3])
    
    os.makedirs(os.path.join(res_dir, 'drawable'), exist_ok=True)
    master_512.save(os.path.join(res_dir, 'drawable', 'app_icon.png'), 'PNG')
    
    os.makedirs(os.path.join('assets', 'icon'), exist_ok=True)
    master_512.save(os.path.join('assets', 'icon', 'app_icon.png'), 'PNG')
    
    print('All mipmap icons and drawable assets generated successfully!')

if __name__ == '__main__':
    generate_icons()
