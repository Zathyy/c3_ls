module lsp::io_handler;
import lsp::translator;

import std::core::log;
import std::core::mem;
import std::io;
import std::collections::list;
import std::net::os;
import libc;
import std::os::win32;

String prev_buffer;

// will be in std lib soon
extern fn int _setmode(int fd, int mode) @if(env::WIN32);
extern fn Win32_HANDLE getStdHandle(Win32_DWORD handle) @cname("GetStdHandle") @if(env::WIN32);
const Win32_DWORD STD_INPUT_HANDLE @if(env::WIN32)  = 0xFFFFFFF6; // ((DWORD)-10)

extern fn Win32_BOOL peekNamedPipe(
	Win32_HANDLE   hNamedPipe,
	Win32_LPVOID  lpBuffer,
	Win32_DWORD    nBufferSize,
	Win32_LPDWORD lpBytesRead = null,
	Win32_LPDWORD lpTotalBytesAvail = null,
	Win32_LPDWORD lpBytesLeftThisMessage = null
) @cname("PeekNamedPipe") @if(env::WIN32);

<*
	Set up stdin for continuous reading
*>
fn void init()
{
	$if env::WIN32:
		_setmode(0, 0x8000); // stdin -> O_BINARY
		_setmode(1, 0x8000); // stdout -> O_BINARY
	$else
		NativeSocket socket = ((NativeSocket)libc::STDIN_FD);
		if (catch err = socket.set_non_blocking(true))
		{
			log::error("Failed to set stdin non blocking: %s", err);
		}
	$endif
}

<*
	Free incomplete message buffer
*>
fn void quit()
{
	if (prev_buffer) 
	{
		mem::free(prev_buffer);
	}
}

faultdef
	NO_NEW_DATA;

fn bool has_input() @if(env::WIN32)
{
	static Win32_HANDLE hStdin = null;
	if (!hStdin) hStdin = getStdHandle(STD_INPUT_HANDLE);

	Win32_DWORD avail_bytes;
	if (peekNamedPipe(hStdin, null, 0, null, &avail_bytes, null))
	{
		return avail_bytes > 0;
	}
	return false;
}

<*
	Reads LSP message from stdin
	@param [in] allocator
	@param [in] message
	@return "LSP message allocated with `allocator`"
	@return? NO_NEW_DATA
	@return? translator::INCOMPLETE_JSON
	@return? translator::INVALID_MESSAGE
*>
fn LspMessage? read(Allocator allocator, String message = {})
{
	if (message == {} && prev_buffer.len > 0)
    {
        // Check if our leftover buffer already contains a complete message
        IoDecodeResult? backlog_decode = translator::decode(allocator, prev_buffer);
        if (catch err = backlog_decode)
        {
			switch (err)
            {
                case translator::INCOMPLETE_JSON:
                    break;
                case translator::INVALID_MESSAGE:
                    log::warn("Wiping corrupted stream backlog chunk to prevent deadlocks.");
                    mem::free(prev_buffer);
                    prev_buffer = {};
                    break;
                default:
                    log::verbose("Backlog check returned unhandled status: %s", err);
            }
        }
		else
		{
			log::verbose("Draining backlogged message directly from memory buffer (%d bytes remaining)", prev_buffer.len - backlog_decode.len);
            
            char* pbptr = prev_buffer;
            defer mem::free(pbptr);

            if (backlog_decode.len < prev_buffer.len)
            {
                prev_buffer = (String)alloc::clone_slice(mem, (char[])prev_buffer[backlog_decode.len..]);
            }
            else
            {
                prev_buffer = {};
            }
            return backlog_decode.message;
		}
    }
	char[] read_buffer;
	if (message != {})
	{
		log::verbose("reading from function param");
		read_buffer = alloc::clone_slice(tmem, (char[])message);
	}
	else
	{
		$if env::WIN32:
      	if (!has_input()) return NO_NEW_DATA~;
		$endif
		read_buffer = load_stdin(tmem);
		if (read_buffer.len == 0) return NO_NEW_DATA~;
		log::verbose("reading from stdin");
	}
	log::debug("got message: %s", (String)read_buffer);

	if (!prev_buffer)
	{
		log::verbose("completely new message");
		prev_buffer = (String)alloc::clone_slice(mem, read_buffer);
	}
	else
	{
		log::verbose("continuing parsing of previous message");
		char* pbptr = prev_buffer;
		defer mem::free(pbptr);
		prev_buffer = prev_buffer.concat(mem, (String)read_buffer);
		log::debug("full message: %s", prev_buffer);
	}

	IoDecodeResult? decode_result = translator::decode(allocator, prev_buffer);
	if (catch excuse = decode_result)
	{
		log::verbose("failed to decode message: %s", excuse);
		switch (excuse)
		{
		case translator::INVALID_MESSAGE:
			mem::free(prev_buffer);
			prev_buffer = {};
		}
	}
	else
	{
		log::verbose("decoded message successfully");
		if (decode_result.len < prev_buffer.len)
		{
			log::verbose("%d bytes remain unhandled; saving", prev_buffer.len - decode_result.len);
			char* pbptr = prev_buffer;
			defer mem::free(pbptr);
			prev_buffer = (String)alloc::clone_slice(mem, (char[])prev_buffer[decode_result.len..]);
		}
		else
		{
			mem::free(prev_buffer);
			prev_buffer = {};
		}
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

const STDIN_ALLOC_LEN @local = 1024;

fn char[] load_stdin(Allocator allocator) @local
{
    InStream stream = io::stdin();
    
    char[] result = alloc::new_array(allocator, char, 0);
    char[STDIN_ALLOC_LEN] tmp_read;
    while (true)
    {
		sz? bytes_read;
		$if env::WIN32:
			static Win32_HANDLE hStdin = null;
            if (!hStdin) hStdin = getStdHandle(STD_INPUT_HANDLE);

            Win32_DWORD dw_bytes_read = 0;
            if (!win32::readFile(hStdin, &tmp_read, STDIN_ALLOC_LEN, &dw_bytes_read, null))
            {
                break;
            }
            bytes_read = (sz)dw_bytes_read;
		$else
			bytes_read = stream.read(&tmp_read);
		$endif

		if (catch err = bytes_read)
		{
			break;
		}

        if (bytes_read <= 0)
        {
            break;
        }

        // Concatenate only the slice of valid bytes read during this iteration
        char[] concatenated = array::concat(allocator, result, tmp_read[:bytes_read]);
        alloc::free(allocator, result);
        result = concatenated;

        // If we read less than the buffer capacity, the stream is fully empty for now
        if (bytes_read < STDIN_ALLOC_LEN)
        {
            break;
        }
    }
    return result;
}
