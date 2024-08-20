package http

import "core:bytes"
import "core:fmt"
import "core:net"
import "core:os"

// Maximum request size
MAX_RECV_BYTES :: 4096
MIN_HTTP_1_BYTES :: 16

Request :: struct {
	Method:   string, // https://www.rfc-editor.org/rfc/rfc2616#section-5.1.1
	URI:      string, // https://www.rfc-editor.org/rfc/rfc2616#section-5.1.2
	Protocol: string, // For rfc2616 this would be HTTP/1.1
	Headers:  map[string]string,
	Body:     []u8,
}

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

	// backlog is the number of connections allowed on the incoming queue.
	// Incoming connections are going to wait in this queue until you accept()
	// this is the limit on how many can queue up
	MAX_TCP_QUEUE_BACKLOG :: 1280
	listen_socket, dial_err := net.listen_tcp(endpoint, MAX_TCP_QUEUE_BACKLOG)
	defer net.close(listen_socket)
	if dial_err != nil {
		fmt.eprintln("Error when dialing", dial_err)
		os.exit(1)
	}

	recv_buffer: [MAX_RECV_BYTES]byte
	for {
		client_socket, client_endpoint, accept_error := net.accept_tcp(listen_socket)
		// Shutdown stops a file descriptor (socket) from being used
		defer net.shutdown(client_socket, .Both)
		// Close frees the file descripter (socket)
		defer net.close(client_socket)

		if accept_error != nil {
			fmt.eprintln("Failed to accept connection", accept_error)
			continue
		}

		// We might not receive the entire payload in a single recv call so we keep
		// calling recv_tcp until we have an exit condition.
		request: Request
		progress: ParseRequestProgress
		for {
			bytes_recv, recv_err := net.recv_tcp(client_socket, recv_buffer[:])
			if recv_err != nil {
				fmt.eprintln("Error receiving data", recv_err)
				break
			}

			// A value of 0 means the client has closed the connection
			if (bytes_recv == 0) {
				break
			}


			if (bytes_recv < MIN_HTTP_1_BYTES) {
				continue
			}

			parse_ok := parse_request(
				recv_buffer[progress.parsed_bytes:bytes_recv],
				&progress,
				&request,
			)

			if (!parse_ok) {
				// TODO: Send 4xx response
				fmt.eprintln("Error parsing request", request, parse_ok)
				os.exit(1)
			}

			if (progress.parsed_bytes >= MAX_RECV_BYTES) {
				// TODO: Send 4xx response
				fmt.eprintln("Request exceeds maximum payload size")
				os.exit(1)
			}

			if (progress.parsed_bytes > 0 && progress.parsed_bytes == progress.expected_bytes) {
				break
			}
		}

		fmt.printfln("Got request: \n %v", request)

		response := "HTTP/1.1 200 OK\r\n\r\nHello, World\r\n"
		// Send data via TCP to client_socket
		// The socket will send as much data as it can but isn't guaranteed to send everything
		// it is expected that we will keep trient to send data until bytes_sent is equal to the payload size
		bytes_sent := 0
		for bytes_sent < len(response) {
			n, send_error := net.send_tcp(client_socket, transmute([]u8)response)
			if send_error != nil {
				fmt.eprintln("Error when sending data", send_error)
				break
			}
			bytes_sent += n
		}
	}

}
