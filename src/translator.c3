module lsp::translator;
import json;

import std::io;
import std::encoding::json;
import std::collections::maybe;
import std::collections::object;
import std::core::string;

faultdef
	INVALID_MESSAGE,
	INCOMPLETE_JSON,
;

struct LspMessage (Printable)
{
	String rpc;
	String method;
	Maybe{Object*} params;

	Allocator allocator;
	Object* contents;
}
fn bool LspMessage.is_initialized(self) @inline => self.contents != null;
fn usz? LspMessage.to_format(&self, Formatter* formatter) @dynamic
	=> formatter.printf("%s", self.contents);
fn void LspMessage.free(&self)
{
	if (self.contents != null) self.contents.free();
}

<*
	Turn data into JSONRPC string
	@param [in] expr
	@return "JSONRPC string allocated with `allocator`"
*>
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

struct IoDecodeResult
{
	LspMessage message;
	usz len;
}
<*
	Decode JSONRPC message
	@param [in] message
	@return "LSP message allocated with `allocator`, as well as length of whole"
		"message"
	@return? INCOMPLETE_JSON
	@return? INVALID_MESSAGE
*>
macro IoDecodeResult? decode(Allocator allocator, String message) => @pool()
{
	const String HEADER_START = "Content-Length: ";
	const String ESCAPE = "\r\n\r\n";
	if (message.len < HEADER_START.len + ESCAPE.len + 1)
	{
		log::verbose("invalid message: too short");
	}
	String[] split = message.split(tmem, ESCAPE);
	if (split.len < 2)
	{
		log::verbose("failed to split message %s", message);
		return INCOMPLETE_JSON?;
	}

	String header = split[0];
	String content_length_str = header[HEADER_START.len..];
	usz content_length @noinit;
	if (catch @try(content_length, content_length_str.to_integer(usz)))
	{
		log::verbose("failed to read content length");
		return INCOMPLETE_JSON?;
	}
	usz message_len = header.len + ESCAPE.len + content_length;
	if (split[1].len < content_length)
	{
		log::verbose("json message smaller than what header says");
		return INCOMPLETE_JSON?;
	}

	String json_message = split[1][:content_length];
	Object* json_obj @noinit;
	if (catch @try(json_obj, json::parse_string(allocator, json_message)))
	{
		log::verbose("failed to read json contents");
		return INCOMPLETE_JSON?;
	}

	log::verbose("successfully read message %s", json_message);

	LspMessage lsp_message = {
		.allocator = allocator,
		.contents = json_obj,
	};
	if (try rpc = json_obj.get_string("jsonrpc"))
	{
		lsp_message.rpc = rpc;
	}
	else
	{
		log::debug("lsp message is missing rpc");
		return INVALID_MESSAGE?;
	}
	if (try method = json_obj.get_string("method"))
	{
		lsp_message.method = method;
	}
	else
	{
		log::debug("lsp message is missing method");
		return INVALID_MESSAGE?;
	}
	if (try params = json_obj.get("params"))
	{
		lsp_message.params = maybe::value{Object*}(params);
	}
	else
	{
		log::verbose("lsp message is missing params");
	}
	return {
		.message = lsp_message,
		.len = message_len
	};
}
