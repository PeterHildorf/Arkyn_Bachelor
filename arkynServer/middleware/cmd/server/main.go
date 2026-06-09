package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"github.com/joho/godotenv"

	"arkyn/middleware/internal/ai"
	"arkyn/middleware/internal/api"
	"arkyn/middleware/internal/config"
	"arkyn/middleware/internal/ocr"
)

func main() {
	// Load .env file if it exists
	if err := godotenv.Load(); err != nil {
		if !os.IsNotExist(err) {
			log.Printf("Warning: could not load .env file: %v", err)
		}
	}

	cfg := config.Load()

	ctx := context.Background()

	visionClient, err := ocr.NewVisionClient(ctx)
	if err != nil {
		log.Fatalf("Failed to initialize Vision OCR client: %v", err)
	}
	defer visionClient.Close()

	claudeClient := ai.NewClaudeClient(cfg.AnthropicAPIKey)

	router := api.NewRouter(visionClient, claudeClient)

	log.Printf("Arkyn middleware server starting on %s", cfg.ServerAddr)
	if err := http.ListenAndServe(cfg.ServerAddr, router); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
