package main

import (
	"context"
	"encoding/json"
	"github.com/redis/go-redis/v9"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Missing DB address")
	}
	client := redis.NewClient(&redis.Options{
		Addr:	  os.Args[1],
		Username: "default",
		Password: os.Getenv("PASSWORD"),
	})

	_, err := client.Info(context.Background()).Result()
	if err != nil {
		log.Fatalf("Failed to connect to DB. Error: %v", err)
	}

	http.HandleFunc("/api/v1/music-albums", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusNotFound)
			return
		}

		key := r.URL.Query().Get("key")

		if key == "" {
			log.Print("Missing key query")
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		k, err := strconv.Atoi(key)
		if err != nil {
			log.Printf("Invalid key received: %s", key)
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		if k < 1 || k > 347 {
			log.Printf("Invalid key received: %d", k)
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
		defer cancel()

		album, err := client.Get(ctx, key).Result()
		if err != nil {
			log.Printf("Failed to receive album for key %s: %v", key, err)
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(output{Album: strings.TrimSpace(album)}); err != nil {
			log.Printf("Failed to encode json: %v", err)
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
	})

	log.Printf("Starting to listen to requests")
	if err := http.ListenAndServe(":9090", nil); err != nil {
		log.Fatal(err)
	}
}

type output struct {
	Album string `json:"album"`
}