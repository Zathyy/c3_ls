module lsp::analysis::completion;

import uri;

struct Context
{
	LspProject* project;
	Uri uri;
	LspPosition position;
}

fn CompletionItem[]? resolve(Context* context)
{

	return {};
}