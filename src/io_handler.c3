module lsp::io_handler;
import lsp::msg_processor;

import std::core::log;
import std::core::mem;
import std::io;
import std::collections::list;
import std::net::os;
import libc;

String prev_buffer;

fn void init()
{
	CInt fd_flags = os::fcntl(libc::STDIN_FD, os::F_GETFL, 0);
	os::fcntl(libc::STDIN_FD, os::F_SETFL, fd_flags | os::O_NONBLOCK);
}
fn void quit()
{
	if (prev_buffer.ptr != null) mem::free(prev_buffer);
}

faultdef
	INCOMPLETE_MESSAGE
;
fn LspMessage? read(Allocator allocator, String message = {}) => @pool()
{
	char[] read_buffer;
	if (message != {})
	{
		log::verbose("reading from function param");
		read_buffer = allocator::clone_slice(tmem, (char[])message);
	}
	else
	{
		read_buffer = load_stdin(tmem);
		if (read_buffer.len == 0) return INCOMPLETE_MESSAGE?;
		log::verbose("reading from stdin");
	}
	log::debug("got message: %s", (String)read_buffer);

	if (prev_buffer.ptr == null)
	{
		log::verbose("initializing `prev_buffer`");
		prev_buffer = (String)allocator::clone_slice(mem, read_buffer);
	}
	else
	{
		log::verbose("appending to `prev_buffer`");
		char* pbptr = prev_buffer;
		defer mem::free(pbptr);
		prev_buffer = prev_buffer.concat(mem, (String)read_buffer);
		log::debug("full message: %s", prev_buffer);
	}

	if (try decoded_message = msg_processor::decode(allocator, prev_buffer))
	{
		log::debug("decoded message successfully");
		mem::free(prev_buffer);
		prev_buffer = {};
		return decoded_message;
	}
	else
	{
		log::debug("failed to decoded message");
		return INCOMPLETE_MESSAGE?;
	}
}

const STDIN_ALLOC_LEN @private = 100;
fn char[] load_stdin(Allocator allocator) @private
{
	usz len;
	char[] result = allocator::new_array(allocator, char, 1)[:0];
	while (true)
	{
		char[] tmp_read = allocator::new_array(tmem, char, STDIN_ALLOC_LEN);
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
		allocator::free(allocator, result);
		result = concatenated;
	}
	return result;
}
