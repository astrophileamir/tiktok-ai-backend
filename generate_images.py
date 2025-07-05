import os
import openai
import requests
from dotenv import load_dotenv

load_dotenv()
openai.api_key = os.getenv("OPENAI_API_KEY")

def generate_images(script, num_images=8, output_dir="images"):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    prompt = f"Motivational, vertical, TikTok-style background for: {script[:100]}"
    image_paths = []
    print(f"[Images] Generating {num_images} images with DALL·E...")
    for i in range(num_images):
        response = openai.images.generate(
            model="dall-e-3",
            prompt=prompt,
            n=1,
            size="1024x1792"  # Supported vertical size
        )
        image_url = response.data[0].url
        if not image_url:
            continue
        image_data = requests.get(image_url).content
        image_path = os.path.join(output_dir, f"image_{i}.png")
        with open(image_path, "wb") as f:
            f.write(image_data)
        image_paths.append(image_path)
        print(f"[Images] Image {i+1} saved to {image_path}")
    print(f"[Images] All images generated: {image_paths}")
    return image_paths

if __name__ == "__main__":
    test_script = "You are capable of amazing things. Keep pushing forward and never give up!"
    print(generate_images(test_script)) 