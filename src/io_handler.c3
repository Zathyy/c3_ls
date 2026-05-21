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
extern fn Win32_BOOL setConsoleMode(Win32_HANDLE handle, Win32_DWORD mode) @cname("SetConsoleMode") @if(env::WIN32);
extern fn Win32_BOOL getConsoleMode(Win32_HANDLE handle, Win32_DWORD* mode) @cname("GetConsoleMode") @if(env::WIN32);
extern fn Win32_HANDLE getStdHandle(Win32_DWORD handle) @cname("GetStdHandle") @if(env::WIN32);
extern fn Win32_BOOL getNumberOfConsoleInputEvents(Win32_HANDLE hHandle, Win32_DWORD* lpCount) @cname("GetNumberOfConsoleInputEvents") @if(env::WIN32);

const Win32_DWORD ENABLE_LINE_INPUT @if(env::WIN32) = 0x0002;
const Win32_DWORD ENABLE_ECHO_INPUT @if(env::WIN32) = 0x0004;

// Standard Handles (32-bit unsigned bit patterns)
const Win32_DWORD STD_INPUT_HANDLE @if(env::WIN32)  = 0xFFFFFFF6; // ((DWORD)-10)
const Win32_DWORD STD_OUTPUT_HANDLE @if(env::WIN32) = 0xFFFFFFF5; // ((DWORD)-11)
const Win32_DWORD STD_ERROR_HANDLE @if(env::WIN32)  = 0xFFFFFFF4; // ((DWORD)-12)

<*
	Set up stdin for continuous reading
*>
fn void init()
{
	$if env::WIN32:
		_setmode(0, 0x8000); // stdin -> O_BINARY
		_setmode(1, 0x8000); // stdout -> O_BINARY

		Win32_HANDLE stdin = getStdHandle(STD_INPUT_HANDLE);
		Win32_DWORD mode;

		if (getConsoleMode(stdin, &mode))
        {
			mode &= ~(ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT);         	
			setConsoleMode(stdin, mode);
        }	
	$else
		NativeSocket socket = ((NativeSocket)libc::STDIN_FD);
		if (catch err = socket.set_non_blocking(true))
		{
			log::error("Failed to set stdin non blocking: %s", err);
		}
	$endif
}

fn bool has_input()
{
    $if env::WIN32:
        static Win32_HANDLE hStdin = null;
		if (!hStdin)
		{
			hStdin = getStdHandle(STD_INPUT_HANDLE);
		}
        Win32_DWORD count = 0;
        getNumberOfConsoleInputEvents(hStdin, &count);
        return count > 0;
    $else
        return true;
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

<*
	Reads LSP message from stdin
	@param [in] allocator
	@param [in] message
	@return "LSP message allocated with `allocator`"
	@return? NO_NEW_DATA
	@return? translator::INCOMPLETE_JSON
	@return? translator::INVALID_MESSAGE
*>
fn LspMessage? read(Allocator allocator, String message = {}) => @pool()
{
	char[] read_buffer;
	if (message != {})
	{
		log::verbose("reading from function param");
		read_buffer = alloc::clone_slice(tmem, (char[])message);
	}
	else
	{
		if (!has_input()) return NO_NEW_DATA~;
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
	sz len;
	char[] result = alloc::new_array(allocator, char, 1)[:0];
	while (true)
	{
		char[] tmp_read = alloc::new_array(tmem, char, STDIN_ALLOC_LEN);
		{
			if (try tmp_len = io::stdin().read(tmp_read) && tmp_len > 0)
			{
				len = tmp_len;
			}
			else
			{
				break;
			}
		}
		char[] concatenated = array::concat(allocator, result, tmp_read[:len]);
		alloc::free(allocator, result);
		result = concatenated;
	}
	return result;
}
