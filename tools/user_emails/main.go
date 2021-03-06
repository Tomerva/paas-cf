package main

import (
	"encoding/json"
	"fmt"
	"github.com/alphagov/paas-cf/tools/user_emails/emails"
	"github.com/cloudfoundry-community/go-cfclient"
	"github.com/jszwec/csvutil"
	"gopkg.in/alecthomas/kingpin.v2"
	"log"
	"os"
)

var (
	apiEndpoint   = kingpin.Flag("api-endpoint", "API endpoint").Default("").Envar("API_ENDPOINT").String()
	apiToken      = kingpin.Flag("api-token", "CF OAuth API token").Default("").Envar("API_TOKEN").String()
	adminEndpoint = kingpin.Flag("admin-endpoint", "PaaS Admin base URI").Default("").Envar("ADMIN_ENDPOINT").String()
	critical      = kingpin.Flag("critical", "Print the contact list for a critical message").Default("false").Envar("CRITICAL").Bool()
	management    = kingpin.Flag("management", "Print the contact list for a message to org management").Default("false").Envar("MANAGEMENT").Bool()
	region        = kingpin.Flag("region-info", "PaaS region targeted").Default("").Envar("MAKEFILE_ENV_TARGET").String()
	format        = kingpin.Flag("format", "Output format. Defaults to CSV. Options: csv, json").Default("csv").Envar("FORMAT").String()
)

var (
	FORMAT_CSV    = "csv"
	FORMAT_JSON   = "json"
	VALID_FORMATS = []string{FORMAT_CSV, FORMAT_JSON}
)

func main() {
	kingpin.Parse()

	if !apiTokenPresent(apiToken) {
		log.Fatal("no API token provided")
		os.Exit(1)
	}

	if !apiEndpointPresent(apiEndpoint) {
		log.Fatal("no API endpoint provided")
		os.Exit(1)
	}

	if !validFormat(format) {
		log.Fatalf("Invalid format '%s'", *format)
	}

	client, err := cfclient.NewClient(&cfclient.Config{
		ApiAddress: *apiEndpoint,
		Token:      *apiToken,
	})

	if err != nil {
		log.Fatal(err)
		os.Exit(1)
	}

	addresses := emails.FetchEmails(client, *critical, *management, *adminEndpoint, location(*region))

	if *format == FORMAT_CSV {
		outputCsv(addresses)
	}

	if *format == FORMAT_JSON {
		outputJson(addresses)
	}
}

func outputJson(addresses []emails.UserDetails) {
	b, err := json.Marshal(addresses)
	if err != nil {
		fmt.Println("error:", err)
		return
	}
	fmt.Println(string(b))
}

func outputCsv(addresses []emails.UserDetails) {
	b, err := csvutil.Marshal(addresses)
	if err != nil {
		fmt.Println("error:", err)
		return
	}
	fmt.Println(string(b))
}

func validFormat(format *string) bool {
	if format == nil {
		return false
	}

	for _, valid := range VALID_FORMATS {
		if valid == *format {
			return true
		}
	}

	return false
}

func location(location string) string {
	switch location {
	case "prod":
		foundry := "Ireland"
		return foundry
	case "prod-lon":
		foundry := "London"
		return foundry
	default:
		foundry := "Not Prod"
		return foundry
	}
}

func apiEndpointPresent(apiEndpoint *string) bool {
	if apiEndpoint == nil || *apiEndpoint == "" {
		return false
	}

	return true
}

func apiTokenPresent(apiToken *string) bool {
	if apiToken == nil || *apiToken == "" {
		return false
	}

	return true
}
