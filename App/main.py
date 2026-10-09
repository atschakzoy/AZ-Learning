from flask import Flask, request, jsonify
from openai import AzureOpenAI
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
import os

load_dotenv()

app = Flask(__name__)
#this block was used to get the key and endpoint from the .env file 
#it replaced with a better version which takes the credentials from keyvault
#client = AzureOpenAI( 
  #  api_key=os.getenv("AZURE_OPENAI_KEY"),
 #   api_version="2024-12-01-preview",
#    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT")
#)

credential = DefaultAzureCredential()
kv_client = SecretClient(
    vault_url=os.getenv("KEY_VAULT_URL"),
    credential=credential
)

api_key = kv_client.get_secret("openai-api-key").value

client = AzureOpenAI(
    api_key=api_key,
    api_version="2024-12-01-preview",
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT")
)

@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json()
    prompt = data.get("prompt")

    response = client.chat.completions.create(
        model=os.getenv("AZURE_OPENAI_DEPLOYMENT"),
        messages=[{"role": "user", "content": prompt}]
    )

    return jsonify({"response": response.choices[0].message.content, "version": "v2"})

if __name__ == "__main__":
   app.run(host="0.0.0.0", debug=True)
