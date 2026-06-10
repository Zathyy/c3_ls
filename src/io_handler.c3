module lsp::io_handler;
import lsp::translator;

import std::core::log;
import std::core::mem;
import std::io;
import std::collections::list;
import std::net::os;
import libc;
import std::os::win32;

// will be in std lib soon
extern fn int _setmode(int fd, int mode) @if(env::WIN32);

<*
 Set up stdin for continuous reading
*>
fn void init()
{
	$if env::WIN32:
		_setmode(0, 0x8000); // stdin -> O_BINARY
		_setmode(1, 0x8000); // stdout -> O_BINARY
	$endif
}

<*
  Reads a protocol-framed LSP message from stdin
  @return "LSP message allocated with `allocator`"
  @return? translator::INVALID_MESSAGE
*>
fn LspMessage? read(Allocator allocator)
{
    InStream stream = io::stdin();
    DString line = dstring::new(tmem);
    defer line.free();

    while (true)
    {
        if (try c = stream.read_byte())
        {
            if (c == '\n') break;
            if (c != '\r') line.append_char(c);
        }
        else
        {
            return translator::INVALID_MESSAGE~;
        }
    }

    String s = line.str_view();
    if (!s.contains("Content-Length:")) return translator::INVALID_MESSAGE~;

    uint content_length = 0;
    if (try cl_pos = s.index_of("Content-Length:"))
    {
        content_length = s[cl_pos + 15..].trim().to_uint() ?? 0;
    }
    if (content_length == 0) return translator::INVALID_MESSAGE~;

    // Consume remaining headers until hitting the blank separator line (\r\n)
    while (true)
    {
        DString hdr = dstring::new(allocator);
        defer hdr.free();
        while (true)
        {
            if (try c = stream.read_byte())
            {
                if (c == '\n') break;
                if (c != '\r') hdr.append_char(c);
            }
            else
            {
                return translator::INVALID_MESSAGE~;
            }
        }
        if (hdr.str_view().len == 0) break; // Found blank line!
    }

    char[] body = mem::new_array(char, content_length);
    sz read_so_far = 0;
    while (read_so_far < content_length)
    {
        sz n = stream.read(body[read_so_far..content_length - 1]) ?? 0;
        if (n == 0)
        {
            mem::free(body);
            return translator::INVALID_MESSAGE~;
        }
        read_so_far += n;
    }

    String json_payload = (String)body[:content_length];
    defer mem::free(body);

    IoDecodeResult? decode_result = translator::decode(allocator, json_payload);
    if (catch err = decode_result)
    {
        log::error("LSP decode error caught: %s", err);
        return translator::INVALID_MESSAGE~;
    }

    return decode_result.message;
}

<*
 @param [in] message
*>
fn void write(String message) @inline
{
	io::print(message);
	io::stdout().flush()!!;
}
