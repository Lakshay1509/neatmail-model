from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from transformers import pipeline, logging
import uvicorn
import os
from dotenv import load_dotenv
import secrets

# Load environment variables from .env file
load_dotenv()

# 1. Setup and Silence noise
logging.set_verbosity_error()

app = FastAPI(title="Email Classification API")

# Security
security = HTTPBearer()
API_TOKEN = os.getenv("API_TOKEN")

if not API_TOKEN:
    raise ValueError("API_TOKEN not found in environment variables")

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if not secrets.compare_digest(credentials.credentials, API_TOKEN):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token"
        )
    return credentials.credentials

# 2. Load the model globally so it stays in memory
# This runs once when the server starts
classifier = pipeline(
    "zero-shot-classification", 
    model="MoritzLaurer/mDeBERTa-v3-base-xnli-multilingual-nli-2mil7"
)

# 3. Define the Request Schema
class EmailRequest(BaseModel):
    sender: str
    subject: str
    body: str
    labels: list[str]

# 4. Define the Classification Logic
@app.post("/classify")
async def classify_email(email: EmailRequest, token: str = Depends(verify_token)):
    # Reconstruct the "Graceful" format
    email_context = f"Sender: {email.sender}\nSubject: {email.subject}\nMessage Body:\n{email.body}"
    
    # Run inference
    output = classifier(email_context, email.labels, multi_label=True)
    
    # Return structured JSON
    return {
        "category": output['labels'][0],
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)