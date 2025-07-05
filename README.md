# TikTok AI Video Generator Backend

## Setup

1. **Clone the repo and navigate to the backend directory:**
   ```sh
   cd "ai agent"
   ```

2. **Create a `.env` file:**
   ```sh
   echo "OPENAI_API_KEY=your_openai_api_key_here" > .env
   ```
   Replace `your_openai_api_key_here` with your actual OpenAI API key.

3. **Install dependencies:**
   ```sh
   pip install -r requirements.txt
   ```

4. **Run the FastAPI server locally:**
   ```sh
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

5. **Test the endpoint:**
   - Send a POST request to `http://localhost:8000/generate-video`.
   - The response will be an `.mp4` video file.

## Notes
- Requires Python 3.8+
- Ensure ffmpeg is installed for moviepy to work:
  ```sh
  brew install ffmpeg
  ``` 