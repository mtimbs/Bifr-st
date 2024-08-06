package http

import "core:bytes"
import "core:fmt"
import "core:net"
import "core:os"

// Maximum request size
MAX_RECV_BYTES :: 4096

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

	// 	backlog is the number of connec-tions allowed on the incoming queue.
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


		// We might not receive the entire payload in a single recv call
		// HTTP standard dictates that two CRLF end the request
		total_bytes_recv := 0
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

			total_bytes_recv += bytes_recv
			if (total_bytes_recv > MAX_RECV_BYTES) {
				break
			}

			// This is only true for a GET request
			last_four_bytes := recv_buffer[total_bytes_recv - 4:total_bytes_recv]
			if (bytes.compare(last_four_bytes, []byte{'\r', '\n', '\r', '\n'}) == 0) {
				break
			}


		}


		fmt.printfln("received: %s", recv_buffer[:total_bytes_recv])

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
		fmt.println("Sent response", response)
	}

}
