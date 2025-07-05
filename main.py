from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, StreamingResponse
import os
from generate_script import generate_script
from generate_voice import generate_voice
from generate_images import generate_images
from create_video import create_video
import json
import time

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def event_stream():
    try:
        # Yield an initial event immediately
        yield f"data: {json.dumps({'section': 'init', 'status': 'Starting generation...'})}\n\n"
        yield f"data: {json.dumps({'section': 'script', 'status': 'Generating script...'})}\n\n"
        script = generate_script()
        yield f"data: {json.dumps({'section': 'script', 'status': 'Script generated', 'script': script})}\n\n"
        yield f"data: {json.dumps({'section': 'voice', 'status': 'Generating voiceover...'})}\n\n"
        audio_path = generate_voice(script)
        yield f"data: {json.dumps({'section': 'voice', 'status': 'Voiceover generated', 'audio_path': audio_path})}\n\n"
        yield f"data: {json.dumps({'section': 'images', 'status': 'Generating images...'})}\n\n"
        image_paths = generate_images(script)
        for idx, img in enumerate(image_paths):
            image_url = f"/images/{os.path.basename(img)}"
            yield f"data: {json.dumps({'section': 'images', 'status': f'Image {idx+1} generated', 'image_path': img, 'image_url': image_url})}\n\n"
        yield f"data: {json.dumps({'section': 'images', 'status': 'All images generated', 'image_paths': image_paths})}\n\n"
        yield f"data: {json.dumps({'section': 'video', 'status': 'Creating video...'})}\n\n"
        video_path = create_video(image_paths, audio_path, script)
        yield f"data: {json.dumps({'section': 'video', 'status': 'Video created', 'video_path': video_path})}\n\n"
        yield f"data: {json.dumps({'section': 'done', 'status': 'done', 'video_path': video_path})}\n\n"
    except Exception as e:
        yield f"data: {json.dumps({'section': 'error', 'status': str(e)})}\n\n"

@app.get("/generate-video-progress")
def generate_video_progress():
    return StreamingResponse(event_stream(), media_type="text/event-stream")

@app.get("/images/{image_name}")
def get_image(image_name: str):
    image_path = os.path.join("images", image_name)
    if os.path.exists(image_path):
        return FileResponse(image_path, media_type="image/png")
    return Response(content="Image not found", status_code=404)

@app.post("/generate-video")
def generate_video():
    try:
        script = generate_script()
        audio_path = generate_voice(script)
        image_paths = generate_images(script)
        video_path = create_video(image_paths, audio_path, script)
        return FileResponse(video_path, media_type="video/mp4", filename="tiktok_ai_video.mp4")
    except Exception as e:
        return Response(content=f"Error: {str(e)}", status_code=500)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True) 