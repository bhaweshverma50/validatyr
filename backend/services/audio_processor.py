import os
import tempfile
import logging
from google import genai

logger = logging.getLogger(__name__)

def transcribe_audio(file_bytes: bytes) -> str:
    """
    Uses Gemini 3 Flash's native multimodal audio understanding to transcribe 
    an uploaded audio file back into text for the idea validation pipeline.
    """
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY environment variable not set.")
        
    client = genai.Client(api_key=api_key)
    
    # Write the raw bytes to a temporary .m4a file so the SDK can upload it
    with tempfile.NamedTemporaryFile(delete=False, suffix=".m4a") as temp_audio:
        temp_audio.write(file_bytes)
        temp_audio_path = temp_audio.name
        
    try:
        logger.info(f"Uploading temporary audio file {temp_audio_path} to Gemini...")
        audio_file = client.files.upload(file=temp_audio_path, config={"mime_type": "audio/mp4"})
        
        prompt = "Listen to this audio clip. It is a user describing their new app or business idea. Transcribe what they are saying exactly word-for-word. Do not add any conversational flair or acknowledgment. Output ONLY the transcription."
        
        logger.info("Transcribing audio with gemini-3-flash-preview...")
        response = client.models.generate_content(
            model='gemini-3-flash-preview',
            contents=[audio_file, prompt]
        )
        
        transcript = response.text.strip()
        logger.info(f"Successfully transcribed audio: '{transcript[:50]}...'")
        return transcript
        
    except Exception as e:
        logger.error(f"Error during audio transcription: {e}")
        raise e
    finally:
        if os.path.exists(temp_audio_path):
            os.remove(temp_audio_path)
