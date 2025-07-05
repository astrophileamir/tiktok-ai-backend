import os
from moviepy.editor import ImageClip, AudioFileClip, concatenate_videoclips, TextClip, CompositeVideoClip
from moviepy.video.tools.subtitles import SubtitlesClip
import moviepy.editor as mp

def create_video(image_paths, audio_path, script, output_path="final_video.mp4"):
    print("[Video] Creating video from images and voiceover...")
    duration_per_image = 60 / len(image_paths)
    clips = []
    for img_path in image_paths:
        img_clip = ImageClip(img_path).set_duration(duration_per_image).resize((1080, 1920))
        clips.append(img_clip)
    video = concatenate_videoclips(clips, method="compose")
    audio = AudioFileClip(audio_path)
    video = video.set_audio(audio)

    # Generate word-by-word subtitles
    print("[Video] Adding word-by-word subtitles...")
    words = script.split()
    n_words = len(words)
    word_duration = audio.duration / n_words
    subtitle_clips = []
    for i, word in enumerate(words):
        start = i * word_duration
        end = (i + 1) * word_duration
        txt_clip = (TextClip(word, fontsize=80, color='white', font='Arial-Bold', size=(1080, None), method='caption')
                    .set_position(('center', 1600))
                    .set_start(start)
                    .set_end(end)
                    .set_opacity(0.8))
        subtitle_clips.append(txt_clip)
    final = CompositeVideoClip([video, *subtitle_clips])
    final.write_videofile(output_path, fps=24, codec='libx264', audio_codec='aac')
    print(f"[Video] Video saved to {output_path}")
    return output_path

if __name__ == "__main__":
    # Example usage
    imgs = [f"images/image_{i}.png" for i in range(8)]
    create_video(imgs, "voice.mp3", "You are capable of amazing things. Keep pushing forward and never give up!") 