package main

import (
	"log"
	"net/http"

	"arkyn/middleware/internal/api"
)

func main() {
	router := api.NewRouter()

	addr := ":8080"
	log.Printf("Arkyn middleware server starting on %s", addr)

	if err := http.ListenAndServe(addr, router); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
