package http_server

import "core:fmt"
import "core:net"
import "core:os"

main :: proc() {
	arguments := os.args
	if (len(arguments) < 1) {
		fmt.eprintln("Please provide an address to connect")
		os.exit(1)
	}
	address := arguments[1]

	endpoint, address_ok := net.parse_endpoint(address)
	if !address_ok {
		fmt.eprintln("Invalid endpoint", address)
		os.exit(1)
	}

	listen_socket, dial_err := net.listen_tcp(endpoint)
	defer net.close(listen_socket)
	if dial_err != nil {
		fmt.eprintln("Error when dialing", dial_err)
		os.exit(1)
	}


	for {
		client_socket, client_endpoint, accept_error := net.accept_tcp(listen_socket)
		defer net.shutdown(client_socket, .Send)

		if accept_error != nil {
			fmt.eprintln("Failed to accept connection", accept_error)
			continue
		}

		response := "HTTP/1.1 200 OK\r\n\r\nHello, World\r\n"
		bytes_sent := 0
		for bytes_sent < len(response) {
			n, send_error := net.send_tcp(client_socket, transmute([]u8)response)
			if send_error != nil {
				fmt.eprintln("Error when sending data", send_error)
				break
			}
			bytes_sent += n
		}
		fmt.println("Sent response", response)
	}

}
