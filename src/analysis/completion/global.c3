module lsp::analysis::completion;

import analyzer::workspace;
import analyzer::core;
import analyzer::cursor;
import analyzer::sema;

import std::collections::list;
import std::collections::map;

import lsp::core;
import uri;

fn void provide_global(Context* ctx, List{CompletionItem}* items)
{
	if (ctx.access != NONE) return;
	
	bool types_only = false;
	Module* current_mod = ctx.section.parent_module;
	
	if (ctx.scope == GLOBAL)
	{
		types_only = true;
	}

	ctx.ws.modules.@each(; mod_name, mod)
	{
		mod.symbols.@each(; symbol_name, symbol_list)
		{
			do SCOPE:
			{
				if (symbol_list.is_empty()) break SCOPE;
				
				if (ctx.prefix.len > 0 && !symbol_name.contains(ctx.prefix)) 
				{
					break SCOPE;
				}
				
				foreach (entry : symbol_list)
				{
					if (!should_include_node(entry.node, mod, current_mod, types_only))
					{
						continue;
					}
					
					add_symbol_completion(items, symbol_name, entry.node, mod_name);
				}
			};
		};
	};
}

fn bool should_include_node(Node* node, Module* mod, Module* current_mod, bool types_only) @local
{
	if (!node || !node.is_valid()) return false;
	
	if (mod.id != current_mod.id)
	{
		if (node.visibility != PUBLIC) return false;

		switch (node.kind)
		{
			case VAR_DECL:
				return false;
			default:
				break;
		}
	}
	
	switch (node.kind)
	{
		case MODULE_DECL:
		case IMPORT_DECL:
			return false;
		default: 
			break;
	}
	
	if (types_only)
	{
		switch (node.kind)
		{
			case FN_DECL:
			case MACRO_DECL:
			case VAR_DECL:
				return false;
			default:
				break;
		}
	}
	
	return true;
}
