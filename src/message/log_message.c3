module lsp::msg_handler::log_message;

import lsp::translator;
import lsp::io_handler;

import dessert;
import derive;

fn void send(String message, MessageType type)
{
	LspMessage res = {
		.rpc = "2.0",
		.method = LOG_MESSAGE,
		.params.log_message = {
			.type = (int)type,
			.message = message
		}
	};

	String response_json = translator::encode(res, tmem);
	io_handler::write(response_json);
}