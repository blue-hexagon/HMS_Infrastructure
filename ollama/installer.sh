curl -fsSL https://ollama.com/install.sh | sudo sh
ollama pull llava:7b
sudo systemctl edit ollama
# Insert the following two lines:
#[Service]
#Environment="OLLAMA_HOST=0.0.0.0:11434"
sudo systemctl daemon-reexec
sudo systemctl restart ollama
