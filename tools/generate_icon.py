"""
Generate the FoodHub app icon: a red square with a white delivery scooter silhouette.
Uses Pillow's drawing primitives to create a clean, modern icon.
"""

from PIL import Image, ImageDraw, ImageFont
import os, math

SIZE = 1024
CENTER = SIZE // 2

def main():
    # Create red background
    img = Image.new('RGBA', (SIZE, SIZE), (229, 57, 53, 255))  # #E53935
    draw = ImageDraw.Draw(img)

    # Draw a stylized delivery scooter/motorcycle silhouette using basic shapes
    # This mimics the Material Icons "delivery_dining" icon style

    white = (255, 255, 255, 255)

    # Scale factor for the icon within the canvas
    s = SIZE / 24  # Material icons use a 24x24 grid

    # === Scooter body ===
    # Main body rectangle
    body_x1 = int(6 * s)
    body_y1 = int(9.5 * s)
    body_x2 = int(17 * s)
    body_y2 = int(13 * s)
    draw.rounded_rectangle([body_x1, body_y1, body_x2, body_y2], radius=int(1.5 * s), fill=white)

    # Handlebar / front section
    handle_x1 = int(14 * s)
    handle_y1 = int(7 * s)
    handle_x2 = int(17 * s)
    handle_y2 = int(10 * s)
    draw.rounded_rectangle([handle_x1, handle_y1, handle_x2, handle_y2], radius=int(0.8 * s), fill=white)

    # Seat area
    seat_x1 = int(7 * s)
    seat_y1 = int(8 * s)
    seat_x2 = int(13 * s)
    seat_y2 = int(10 * s)
    draw.rounded_rectangle([seat_x1, seat_y1, seat_x2, seat_y2], radius=int(0.8 * s), fill=white)

    # Food box on back
    box_x1 = int(4.5 * s)
    box_y1 = int(6 * s)
    box_x2 = int(10 * s)
    box_y2 = int(9 * s)
    draw.rounded_rectangle([box_x1, box_y1, box_x2, box_y2], radius=int(1 * s), fill=white)

    # Box top handle
    draw.rounded_rectangle(
        [int(6 * s), int(4.5 * s), int(8.5 * s), int(6.5 * s)],
        radius=int(0.6 * s), fill=white
    )

    # === Wheels ===
    wheel_r = int(2.3 * s)
    # Back wheel
    bw_cx, bw_cy = int(7.5 * s), int(15.5 * s)
    draw.ellipse([bw_cx - wheel_r, bw_cy - wheel_r, bw_cx + wheel_r, bw_cy + wheel_r], fill=white)
    # Inner circle (red, to make it look like a wheel)
    inner_r = int(1.2 * s)
    draw.ellipse([bw_cx - inner_r, bw_cy - inner_r, bw_cx + inner_r, bw_cy + inner_r], fill=(229, 57, 53, 255))
    # Hub
    hub_r = int(0.5 * s)
    draw.ellipse([bw_cx - hub_r, bw_cy - hub_r, bw_cx + hub_r, bw_cy + hub_r], fill=white)

    # Front wheel
    fw_cx, fw_cy = int(16.5 * s), int(15.5 * s)
    draw.ellipse([fw_cx - wheel_r, fw_cy - wheel_r, fw_cx + wheel_r, fw_cy + wheel_r], fill=white)
    draw.ellipse([fw_cx - inner_r, fw_cy - inner_r, fw_cx + inner_r, fw_cy + inner_r], fill=(229, 57, 53, 255))
    draw.ellipse([fw_cx - hub_r, fw_cy - hub_r, fw_cx + hub_r, fw_cy + hub_r], fill=white)

    # Connector between body and wheels (forks)
    fork_w = int(0.8 * s)
    # Back fork
    draw.rectangle([bw_cx - fork_w//2, body_y2, bw_cx + fork_w//2, bw_cy - wheel_r + int(0.3*s)], fill=white)
    # Front fork
    draw.rectangle([fw_cx - fork_w//2, body_y2, fw_cx + fork_w//2, fw_cy - wheel_r + int(0.3*s)], fill=white)

    # Save
    out_dir = os.path.dirname(os.path.abspath(__file__))
    out_path = os.path.join(os.path.dirname(out_dir), 'assets', 'icon', 'app_icon.png')
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path, 'PNG')
    print(f'Icon saved to: {out_path}')

if __name__ == '__main__':
    main()
