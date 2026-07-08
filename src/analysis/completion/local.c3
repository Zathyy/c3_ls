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
	
	ModuleSection* sec = ctx.section;
	SemaScope* root = &sec.scope;
	SemaScope* leaf = sema::find_deepest_scope(root, (int)ctx.offset);
	List{SemaVar} symbols = sema::collect_visible_symbols(tmem, leaf, (int)ctx.offset);
	foreach (symbol : symbols)
    {
		if (!symbol.def) continue;
		
		VarDecl* decl = symbol.def.as(VarDecl);
        Cursor var_cursor = { .node = symbol.def };
        String name = var_cursor.spelling(tmem) ?? "";

        if (ctx.prefix.len > 0 && !name.contains(ctx.prefix)) continue;
		
		Cursor type_cursor = { decl.type };
		String type_name;
		if (decl.type)
		{
			type_name = type_cursor.raw_type_identifier() ?? "";
		}
		
        String details;
		CompletionItemKind kind;
		switch (true)
		{
		case decl.flags.is_const:
			kind = CONSTANT;
			details = string::tformat("(constant) %s", type_name);
			break;
		case decl.var_kind == VAR_GLOBAL:
			kind = VARIABLE;
			details = string::tformat("(global) %s", type_name);
			break;
		case decl.var_kind == VAR_PARAM:
			kind = VARIABLE;
			details = string::tformat("(param) %s", type_name);
			break;
		case decl.var_kind == VAR_LOCAL:
			kind = VARIABLE;
			details = string::tformat("(local) %s", type_name);
			break;
		default:
			kind = VARIABLE;
			details = string::tformat("(local) %s", type_name);
		}
		
        items.push({ 
            .label = name, 
            .kind = kind, 
            .detail = details,
            .sort_text = string::tformat("0001_%s", name)
        });
    }
}
