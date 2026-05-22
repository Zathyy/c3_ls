module lsp::msg_handler::text_opened;
import lsp::msg_handler @norecurse;
import lsp::translator;

import std::io;
import std::collections::maybe;
import std::collections::object;

import dessert;
import derive;

$expand(derive(LspDidOpenTextDocumentNotification::name, dessert));
struct LspDidOpenTextDocumentNotification
{
	inline LspNotification notif;
	struct params
	{
		String uri;
		String languageId;
		int version;
		String text;
	}
}

fn LspDidOpenTextDocumentNotification? parse_message(LspMessage message)
{
	LspDidOpenTextDocumentNotification self = {
		.notif = msg_handler::get_notification_struct(message)!,
	};

	log::info("parsed didOpenTextDocument notification");
	return self;
}
