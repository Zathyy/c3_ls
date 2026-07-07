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
				.documentation = { .value = kw.docs },
				.kind = KEYWORD,
				.sort_text = string::tformat("0010_%s", kw.name),
			});
		}
	}
}

<*
 ffoooo basdarsfdasfasfas
*>
fn void add_symbol_completion(Context* ctx, List{CompletionItem}* items, String symbol_name, Node* node, String base_identifier, String prefix = "")
{
	if (!node) return;
	
	CompletionItemKind item_kind = CompletionItemKind.VALUE; 
	String type_desc = "Symbol";
	String insert_text = symbol_name;
	if (prefix.len > 0 && prefix.starts_with("@"))
	{
		insert_text = symbol_name.strip_prefix("@");
	}
	
	InsertTextFormat format = PLAIN_TEXT;

	switch (node.kind)
	{
		case FN_DECL:
			item_kind = FUNCTION;
			type_desc = "fn";
			insert_text = string::tformat("%s($1)", insert_text);
			format = SNIPPET;
			break;
		
		case MACRO_DECL:
			item_kind = FUNCTION;
			type_desc = "macro";
			insert_text = string::tformat("%s($1)", insert_text);
			format = SNIPPET;
			break;

		case INTERFACE_DECL:
			item_kind = INTERFACE;
			type_desc = "interface";
			insert_text = string::tformat("%s($1)", insert_text);
			format = SNIPPET;
			break;
			
		case STRUCT_DECL:
			item_kind = STRUCT;
			type_desc = "struct";
			break;

		case ENUM_DECL:
			item_kind = ENUM;
			type_desc = "enum";
			break;

		case VAR_DECL:
			{
				VarDecl* decl = node.as(VarDecl);
				if (decl.flags.is_const)
				{
					item_kind = CONSTANT;
					type_desc = "constant";
					break;
				}
				
				item_kind = VARIABLE;
				type_desc = "global var";
				break;
			}
		default:
			break;
	}
	
	String detail_string = string::tformat("%s via %s", type_desc, base_identifier);

	String filter_text = symbol_name;
	if (filter_text.len > 0 && filter_text[0] == '@')
	{
		filter_text = filter_text[1..];
	}
	
	items.push({
		.label = symbol_name,
		.kind = item_kind,
		.detail = detail_string,
		.insert_text = insert_text,
		.insert_text_format = format,
		.filter_text = filter_text,
		.sort_text = string::tformat("0001_%s", symbol_name),
		.data = string::tformat("%d;%s", ctx.section.id, symbol_name)
	});
}