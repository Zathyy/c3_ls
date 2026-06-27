module lsp;

import dessert;
import derive;

$expand(derive(CompletionOptions::name, dessert));
struct CompletionOptions @DStruct({ .rename_all = CAMEL_CASE })
{
	String[] trigger_characters;
	String[] all_commit_characters;
	bool resolve_provider;
	struct completion_item 
	{
		bool label_detail_support;
	}
}

<*
	https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#serverCapabilities
*>
$expand(derive(LspServerCapabilities::name, dessert));
struct LspServerCapabilities @DStruct({ .rename_all = CAMEL_CASE })
{
	TextDocumentSyncOptions text_document_sync;
	CompletionOptions completion_provider;
	bool hover_provider;
	bool definition_provider;
}
