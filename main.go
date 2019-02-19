package main

import (
	"flag"
	"fmt"
	"log"

	"github.com/gorilla/websocket"
)

var url = flag.String("url", "ws://localhost:8989/ws", "websocket address")

func main() {
	flag.Parse()

	log.Println("connecting to:", *url)
	c, _, err := websocket.DefaultDialer.Dial(*url, nil)
	if err != nil {
		log.Fatalln("dial:", err)
	}
	defer func() {
		if err := c.Close(); err != nil {
			fmt.Println("close:", err)
			return
		}
	}()
	defer func() {
		if err := c.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseNormalClosure, "")); err != nil {
			log.Println("write close:", err)
			return
		}
	}()

	for {
		_, message, err := c.ReadMessage()
		if err != nil {
			log.Println("read:", err)
			return
		}
		fmt.Println(string(message))
	}
