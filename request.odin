// https://www.rfc-editor.org/rfc/rfc2616#section-5
package http
import "core:bytes"
import "core:fmt"
Request :: struct {
	Method:   string, // https://www.rfc-editor.org/rfc/rfc2616#section-5.1.1
	URI:      string, // https://www.rfc-editor.org/rfc/rfc2616#section-5.1.2
	Protocol: string, // For rfc2616 this would be HTTP/1.1
	Headers:  map[string]string,
}

parse_request :: proc(payload: []byte) -> Request {
	request: Request
	header_start_index := get_request_line(payload, &request)
	get_headers(payload[header_start_index:], &request)

	return request
}

// https://www.rfc-editor.org/rfc/rfc2616#section-5.1
get_request_line :: proc(payload: []byte, request: ^Request) -> int {
	// The Request-Line begins with a method token, followed by the
	// Request-URI and the protocol version, and ending with CRLF. The
	// elements are separated by SP characters. No CR or LF is allowed
	// except in the final CRLF sequence.

	// TODO: I don't love this approach. Probably a better way but escapes me atm
	// Iterator for request buffer
	i := 0
	// Interator for number of values extracted
	j := 0
	// Positing in request buffer since last SP character
	k := 0

	// Iterate until we get CLRF
	for {
		// If the next byte is a SP character, store the current
		// window in the res parameters relevant index
		if (bytes.compare(payload[i:i + 1], []byte{' '}) == 0) {
			switch j {
			case 0:
				request.Method = transmute(string)payload[k:i]
			case 1:
				request.URI = transmute(string)payload[k:i]
			}
			k = i + 1
			j += 1
		}

		// If we have CLRF then we are at the end. Take everything
		// since the last checkpoint and that is your protocol
		if (bytes.compare(payload[i:i + 2], []byte{'\r', '\n'}) == 0) {
			request.Protocol = transmute(string)payload[k:i]
			break
		}
		i += 1
	}

	// We are going to return the index of the end of the request-line
	// so that we can pass a slice for header extraction and avoid parsing
	// this part of the request again.
	return i
}

// https://www.rfc-editor.org/rfc/rfc2616#section-5.3
get_headers :: proc(payload: []byte, request: ^Request) {
	key_start, value_start := 0, 0
	key: string

	// We know headers end in a double CLRF so we can just ignore the last one
	for i in 0 ..< len(payload) - 2 {
		if (bytes.compare(payload[i:i + 1], []byte{':'}) == 0) {
			key = transmute(string)payload[key_start:i]
			// fmt.printfln("Header Key: '%s'", key)
			value_start = i + 2
		}
		if (bytes.compare(payload[i:i + 2], []byte{'\r', '\n'}) == 0) {
			value := transmute(string)payload[value_start:i]
			// fmt.printfln("Header Value: '%s'", value)
			request.Headers[key] = value
			key_start = i + 2
		}
	}

}
