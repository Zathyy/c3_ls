module lsp::analysis::completion;

import analyzer::workspace;
import analyzer::core;
import analyzer::cursor;
import analyzer::sema;

import std::collections::list;
import std::collections::map;

import lsp::core;
import uri;

fn void provide_keywords(Context* ctx, List{CompletionItem}* items)
{
	if (ctx.access != NONE) return;

	foreach (kw : lsp::Keywords::values)
	{
		switch (ctx.scope)
		{
			case GLOBAL:
				if (!kw.is_top_level()) continue; 
				break;

			case CONTAINER:
				if (!kw.is_container()) continue;
				break;

			case EXECUTION:
				if (!kw.is_statement() && !kw.is_expression()) continue;
				break;
				
			case TYPE_ASSIGNMENT:
				if (!kw.is_value()) continue;
				break;
			default:
		}
		if (ctx.prefix.len == 0 || kw.name.starts_with(ctx.prefix))
		{
			items.push({
				.label = kw.name,
				.documentation = kw.docs,
				.kind = KEYWORD,
				.sort_text = string::tformat("0010_%s", kw.name),
			});
		}
	}
}
