module lsp::msg_processor;
import json;

import std::io;
import std::encoding::json;
import std::collections::object;
import std::core::string;

faultdef INVALID_MESSAGE;

struct LspMessage (Printable)
{
	String method;
	Object* contents;

	Allocator allocator;
}
fn usz? LspMessage.to_format(&self, Formatter* formatter) @dynamic
	=> formatter.printf("%s", self.contents);
fn void LspMessage.free(&self)
{
	if (self.contents != null) self.contents.free();
}

macro String encode(expr, Allocator allocator, int indent = 0) => @pool()
{
	log::verbose("encoding message type %s", $typeof(expr).nameof);
	// TODO: handle encoding error
	String expr_json = json::to_json(expr, tmem, indent)!!;
	usz expr_size = expr_json.len;
	log::verbose("message size: %d", expr_size);

	return string::format(allocator,
		"Content-Length: %d\r\n\r\n%s",
		expr_size,
		expr_json
	);
}

<*
	@return? INVALID_MESSAGE
*>
macro LspMessage? decode(Allocator allocator, String message) => @pool()
{
	const String HEADER_START = "Content-Length: ";
	if (message.len < HEADER_START.len + "\r\n\r\n".len + 1)
	{
		log::debug("invalid message: too short");
	}
	String[] split = message.split(tmem, "\r\n\r\n");
	if (split.len != 2)
	{
		log::debug("failed to split message %s", message);
		return INVALID_MESSAGE?;
	}

	String header = split[0];
	String content_length_str = header["Content-Length: ".len..];
	usz content_length @noinit;
	if (catch @try(content_length, content_length_str.to_integer(usz)))
	{
		log::debug("failed to read content length");
		return INVALID_MESSAGE?;
	}

	String json_message = split[1];
	Object* json_obj @noinit;
	if (catch @try(json_obj, json::parse_string(allocator, json_message)))
	{
		log::debug("failed to read json contents");
		return INVALID_MESSAGE?;
	}

	log::debug("successfully read message");

	return {
		.method = json_obj.get_string("method") ?? INVALID_MESSAGE?!,
		.contents = json_obj,
		.allocator = allocator,
	};
}
