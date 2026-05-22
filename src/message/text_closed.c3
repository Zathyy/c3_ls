module lsp::msg_handler::text_closed;
import lsp::msg_handler @norecurse;
import lsp::translator;

import std::io;
import std::collections::maybe;
import std::collections::object;

import dessert;
import derive;

$expand(derive(LspDidCloseTextDocumentNotification::name, dessert::serialize));
struct LspDidCloseTextDocumentNotification
{
	inline LspNotification notif;
	struct params
	{
		String uri;
	}
}

fn LspDidCloseTextDocumentNotification? parse_message(LspMessage message)
{
	LspDidCloseTextDocumentNotification self = {
		.notif = msg_handler::get_notification_struct(message)!,
	};

	log::info("parsed didCloseTextDocument notification");
	return self;
}
