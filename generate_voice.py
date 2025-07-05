import os
import openai
from dotenv import load_dotenv

load_dotenv()
openai.api_key = os.getenv("OPENAI_API_KEY")

def generate_voice(script, output_path="voice.mp3"):
    print("[Voice] Generating voiceover using OpenAI TTS...")
    response = openai.audio.speech.create(
        model="tts-1",
        voice="alloy",
        input=script
    )
    with open(output_path, "wb") as f:
        f.write(response.content)
    print(f"[Voice] Voiceover saved to {output_path}")
    return output_path

if __name__ == "__main__":
    test_script = "You are capable of amazing things. Keep pushing forward and never give up!"
    print(generate_voice(test_script)) 