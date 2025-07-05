import os
from dotenv import load_dotenv
import openai

load_dotenv()
openai.api_key = os.getenv("OPENAI_API_KEY")

def generate_script():
    print("[Script] Generating motivational TikTok script...")
    prompt = (
        "Write a 60-second motivational TikTok script. "
        "The script should be energetic, positive, and suitable for a vertical video. "
        "Keep it concise and inspiring."
    )
    response = openai.chat.completions.create(
        model="gpt-3.5-turbo",
        messages=[{"role": "user", "content": prompt}],
        max_tokens=300,
        temperature=0.8,
    )
    message = response.choices[0].message.content
    script = message.strip() if message else ""
    print("[Script] Script generated:")
    print(script)
    return script

if __name__ == "__main__":
    print(generate_script()) 