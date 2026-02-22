import os
from dotenv import load_dotenv
from google import genai
from google.genai import types

load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")
client = genai.Client(api_key=api_key)

response = client.models.generate_content(
    model='gemini-3-flash-preview',
    contents='Search the web for opinions and reviews on the app "Manus AI". Summarize what people love and hate. Quote your sources.',
    config=types.GenerateContentConfig(
        tools=[{"google_search": {}}],
        temperature=0.2
    )
)
print(response.text)
