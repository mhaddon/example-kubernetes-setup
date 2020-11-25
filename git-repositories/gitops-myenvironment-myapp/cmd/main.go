package main

import (
	"fmt"
	"log"
	"os"
	"net/http"
)

func homePage(w http.ResponseWriter, r *http.Request){
	_, err := fmt.Fprintf(w, "Hello World!"); if err != nil {
		log.Fatalf("[MyApp][homePage] %v", err)
	}
}

func main() {
	log.Print("[MyApp] Started.")
	log.Printf("[MyApp] Secret: %v", os.Getenv("MY_SECRET"))
	log.Printf("[MyApp] Config: %v", os.Getenv("MY_CONFIG"))

	http.HandleFunc("/", homePage)
	log.Fatal(http.ListenAndServe(":8080", nil))
}