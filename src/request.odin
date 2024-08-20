// https://www.rfc-editor.org/rfc/rfc2616#section-5
package http
import "core:bytes"
import "core:fmt"
import "core:strconv"


ParseRequestProgress :: struct {
	expected_bytes: int,
	parsed_bytes:   int,
	parsed_headers: bool,
}
parse_request :: proc(
	payload: []byte,
	progress: ^ParseRequestProgress,
	request: ^Request,
) -> (
	ok: bool,
) {
	if (progress.parsed_bytes == 0) {
		progress.parsed_bytes += get_request_line(payload, request)
		// fmt.printfln("Got Request Line: \n %v", request)
	}

	if (progress.parsed_bytes > 0) {
		completed, header_bytes := get_headers(payload[progress.parsed_bytes:], request)
		progress.parsed_headers = completed
		progress.parsed_bytes += header_bytes
	}

	if (progress.parsed_headers) {
		content_length := request.Headers["Content-Length"]
		if (content_length == "") {
			progress.expected_bytes = progress.parsed_bytes
			return true
		}
		// fmt.println("Content-Length: ", request.Headers["Content-Length"])

		body_length, parse_ok := strconv.parse_int(content_length, 10)
		if (!parse_ok) {
			return false
		}
		progress.expected_bytes = progress.parsed_bytes + body_length
		// fmt.println("Expected bytes:", progress.expected_bytes)
		// fmt.println("Parsed bytes:", progress.parsed_bytes)
		// fmt.println("Payload Length:", len(payload))

		if (progress.parsed_bytes + body_length == progress.expected_bytes) {
			body := payload[len(payload) - body_length:]
			request.Body = body

			progress.parsed_bytes += len(request.Body)
			// fmt.println("Expected bytes:", progress.expected_bytes)
			// fmt.println("Parsed bytes:", progress.parsed_bytes)
		}

	}

	return true
}

// https://www.rfc-editor.org/rfc/rfc2616#section-5.1
get_request_line :: proc(payload: []byte, request: ^Request) -> (parsed_bytes: int) {
	// The Request-Line begins with a method token, followed by the
	// Request-URI and the protocol version, and ending with CRLF. The
	// elements are separated by SP characters. No CR or LF is allowed
	// except in the final CRLF sequence.
	bytes_read := 0
	k := 0 // Position in request buffer since last SP character
	// Iterate until we get CLRF
	for i in 0 ..< len(payload) - 2 {
		// If the next byte is a SP character, store the current
		// window in the res parameters relevant index
		if (bytes.compare(payload[i:i + 1], []byte{' '}) == 0) {
			if (request.Method == "") {
				request.Method = transmute(string)payload[k:i]
			} else {
				request.URI = transmute(string)payload[k:i]
			}
			k = i + 1
		}

		// If we have CLRF then we are at the end. Take everything
		// since the last checkpoint and that is your protocol
		if (bytes.compare(payload[i:i + 2], []byte{'\r', '\n'}) == 0) {
			request.Protocol = transmute(string)payload[k:i]
			bytes_read = i + 2
			break
		}
	}

	return bytes_read

}

// https://www.rfc-editor.org/rfc/rfc2616#section-5.3
get_headers :: proc(payload: []byte, request: ^Request) -> (finished: bool, parsed_bytes: int) {
	bytes_read := 0
	completed := false
	key_start, value_start := 0, 0
	key: string

	// We know headers end in a double CLRF so we can just ignore the last one
	for i in 0 ..< len(payload) {
		if (bytes.compare(payload[i:i + 1], []byte{':'}) == 0) {
			key = transmute(string)payload[key_start:i]
			// fmt.printfln("Header Key: '%s'", key)
			value_start = i + 2
		}
		if (bytes.compare(payload[i:i + 2], []byte{'\r', '\n'}) == 0) {
			if (key == "") {
				completed = true
				bytes_read += 2
				break
			}
			value := transmute(string)payload[value_start:i]
			request.Headers[key] = value
			bytes_read += (i + 2) - key_start
			key = ""
			key_start = i + 2
		}
	}

	return completed, bytes_read
}
