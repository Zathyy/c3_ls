module lsp::analysis::completion;

import analyzer::workspace;
import analyzer::core;
import analyzer::cursor;
import analyzer::sema;

import std::collections::list;
import std::collections::map;

import lsp::core;
import uri;

fn void provide_locals(Context* ctx, List{CompletionItem}* items)
{
	if (ctx.scope != EXECUTION) return;
	if (ctx.access != NONE) return;

	Node* parent = ctx.top_level_node;
	ModuleSection* sec = ctx.section;
	if (!parent || !parent.is_valid()) 
	{
		log::warn("No parent");
		return;
	}
	
	if FUNC: (parent.kind == FN_DECL)
	{
		FnDecl* func = parent.as(FN_DECL);
		foreach (param_node : func.params)
		{
			if (!param_node || !param_node.is_valid() || param_node.kind != VAR_DECL)
			{
				continue;
			}

			VarDecl* param = param_node.as(VAR_DECL);
			Cursor cursor = { sec, param_node };
			String name = cursor.spelling(tmem) ?? "";
			if (ctx.prefix.len > 0 && !name.contains(ctx.prefix)) break;
			items.push({ 
				.label = name, 
				.kind = VARIABLE, 
				.detail = string::tformat("(parameter) %s", name),
				.sort_text = string::tformat("0001_%s", name)
			});
		}
		
		Node* body = func.body;
		if (!body) break FUNC;
		switch (body.kind)
		{
			case COMPOUND_STMT:
				{
					CompoundStmt* comp = body.as(COMPOUND_STMT);
					foreach (stmt : comp.statements)
					{
						switch (stmt.kind)
						{
							case VAR_DECL:
								VarDecl* local = stmt.as(VAR_DECL);
								Cursor field_cursor = { sec, stmt };
								String name = field_cursor.spelling(tmem) ?? "";
								if (ctx.prefix.len > 0 && !name.contains(ctx.prefix)) break;
								items.push({ 
									.label = name, 
									.kind = VARIABLE, 
									.detail = string::tformat("(local) %s", name),
									.sort_text = string::tformat("0001_%s", name)
								});
							default:
								break;
						}
					}
				}
			default: break;
		}
	}
	else if (parent.kind == MACRO_DECL)
	{
		MacroDecl* mac = parent.as(MACRO_DECL);
		foreach (param_node : mac.params)
		{
			if (param_node.kind != VAR_DECL) continue;

			VarDecl* param = param_node.as(VAR_DECL);
			Cursor cursor = { sec, param_node };
			String name = cursor.spelling(tmem) ?? "";
			items.push({ .label = name, .kind = VARIABLE, .detail = "Macro Argument" });
		}
	}
}
