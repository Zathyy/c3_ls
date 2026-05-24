module lsp::translator;

import std::io;
import std::encoding::json;
import std::collections::maybe;
import std::collections::object;
import std::core::string;

import dessert;
import derive;

faultdef
	INVALID_MESSAGE,
	INCOMPLETE_JSON,
;

$expand(derive(LspMessage::name, dessert));
struct LspMessage
{
	String rpc @DField({ .rename = "jsonrpc" });
	MessageKind method;
	MessageParams params @DField({ .tagged = { .by = "method", .inlined = true, .unmapped.as = EMPTY_STRUCT } });
	Allocator allocator @DField({ .skip = true });
  	Maybe{int} id;
}

fn void LspMessage.free(&self)
{
	self.rpc.free(self.allocator);
}

<*
	Turn data into JSONRPC string
	@param [in] expr
	@return "JSONRPC string allocated with `allocator`"
*>
macro String encode(expr, Allocator allocator, int indent = 0) => @pool()
{
	log::verbose("encoding message type %s", $Typeof(expr)::name);
	// TODO: handle encoding error
	String expr_json = ser::serialize(&&json::string_serializer(), expr)!!;
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
macro IoDecodeResult? decode(Allocator allocator, String message)
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
		return INCOMPLETE_JSON~;
	}

	String header = split[0];
	String content_length_str = header[HEADER_START.len..];
	ulong content_length;
	if (catch @try(content_length, content_length_str.to_ulong()))
	{
		return INCOMPLETE_JSON~;
	}
	usz message_len = header.len + ESCAPE.len + content_length;
	if (split[1].len < content_length)
	{
		log::verbose("json message smaller than what header says");
		return INCOMPLETE_JSON~;
	}

	String json_message = split[1][:content_length];
	
	sz method_idx = json_message.index_of("\"method\":") ?? -1;
	sz params_idx = json_message.index_of("\"params\":") ?? -1;
	// if the method is after the params, we move it at the start of the json string
	// so it can be deserialized properly
	if (params_idx != -1 && method_idx > params_idx)
	{
		method_idx = json_message.rindex_of("\"method\":")!!;
		int method_len = "\"method\":".len;
		int quote_count = 0;
		while (quote_count != 2)
		{
			if (json_message[method_idx + method_len] == '"') quote_count++;
			method_len++;
		}

		json_message = string::tformat(
			"{%s,%s%s", 
			json_message[method_idx:method_len], 
			json_message[1..method_idx - 2], json_message[method_idx + method_len..]
		);
	}

	LspMessage? lsp_message = des::deserialize{LspMessage}(&&json::debug_deserializer(json_message));
	if (catch err = lsp_message)
	{
		return err~;
	}
	lsp_message.allocator = allocator;
	lsp_message.rpc = lsp_message.rpc.copy(allocator);

	return {
		.message = lsp_message,
		.len = message_len
	};
}
