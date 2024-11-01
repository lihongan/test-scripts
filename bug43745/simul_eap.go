package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"time"
)

func httpClient() *http.Client {
	client := &http.Client{
		Transport: &http.Transport{
			MaxIdleConnsPerHost: 20,
		},
		Timeout: 10 * time.Second,
	}

	return client
}

func sendRequest(client *http.Client, method string) []byte {
	url := "http://mytest.apps.hongli-az.qe.azure.devcluster.openshift.com"
	req, err := http.NewRequest(method, url, nil)
	if err != nil {
		log.Fatalf("Error Occured. %+v", err)
	}

	response, err := client.Do(req)
	if err != nil {
		log.Printf("Error sending request to server. %+v", err)
		return nil
	}

	// Close the connection to reuse it
	defer response.Body.Close()

	body, err := ioutil.ReadAll(response.Body)
	if err != nil {
		log.Fatalf("Couldn't parse response body. %+v", err)
	}

	return body
}

func main() {
	//uri := "http://mytest.apps.hongli-az.qe.azure.devcluster.openshift.com"
	method := http.MethodGet
	client := httpClient()

	response := sendRequest(client, method)
	log.Println("Response Body:", string(response))

	fmt.Println(">>> please update the route, waiting 240s and try again")
	time.Sleep(240 * time.Second)
	response = sendRequest(client, method)
	log.Println("Response Body:", string(response))

	fmt.Println(">>> waiting 6s and try again")
	time.Sleep(6 * time.Second)
	response = sendRequest(client, method)
	log.Println("Response Body:", string(response))

	fmt.Println(">>> waiting 6s and try again")
	time.Sleep(6 * time.Second)
	response = sendRequest(client, method)
	log.Println("Response Body:", string(response))
}
