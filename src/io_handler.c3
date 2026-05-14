module lsp::io_handler;
import lsp::translator;

import std::core::log;
import std::core::mem;
import std::io;
import std::collections::list;
import std::net::os;
import libc;

String prev_buffer;

<*
	Set up stdin for continuous reading
*>
fn void init()
{
	int fd_flags = os::fcntl((NativeSocket) libc::STDIN_FD, os::F_GETFL, 0);
	os::fcntl((NativeSocket) libc::STDIN_FD, os::F_SETFL, fd_flags | os::O_NONBLOCK);
}
<*
	Free incomplete message buffer
*>
fn void quit()
{
	if (prev_buffer.ptr != null) mem::free(prev_buffer);
}

faultdef
	NO_NEW_DATA,
;
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
		read_buffer = load_stdin(tmem);
		if (read_buffer.len == 0) return NO_NEW_DATA~;
		log::verbose("reading from stdin");
	}
	log::debug("got message: %s", (String)read_buffer);

	if (prev_buffer.ptr == null)
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
