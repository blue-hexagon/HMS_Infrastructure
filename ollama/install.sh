curl -fsSL https://ollama.com/install.sh | sudo sh
ollama pull llava:7b
sudo systemctl edit ollama
#[Service]
#Environment="OLLAMA_HOST=0.0.0.0:11434"
sudo systemctl daemon-reexec
sudo systemctl restart ollama
sudo ufw allow from 192.168.10.55 to any port 11434
sudo ufw enable
