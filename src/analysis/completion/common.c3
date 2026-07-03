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

fn void add_symbol_completion(List{CompletionItem}* items, String symbol_name, Node* node, String base_identifier)
{
	if (!node) return;

	CompletionItemKind item_kind = CompletionItemKind.VALUE; 
	String type_desc = "Symbol";
	String insert_text = symbol_name;

	switch (node.kind)
	{
		case FN_DECL:
			item_kind = FUNCTION;
			type_desc = "fn";
			insert_text = string::tformat("%s()", insert_text);
			break;

		case MACRO_DECL:
			item_kind = FUNCTION;
			type_desc = "macro";
			insert_text = string::tformat("%s()", insert_text);
			break;
			
		case INTERFACE_DECL:
			item_kind = INTERFACE;
			type_desc = "interface";
			insert_text = string::tformat("%s()", insert_text);
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
				VarDecl* decl = node.as(VAR_DECL);
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
	
	items.push({
		.label = symbol_name,
		.kind = item_kind,
		.detail = detail_string,
		.insert_text = insert_text,
		.sort_text = string::tformat("0001_%s", symbol_name)
	});
}