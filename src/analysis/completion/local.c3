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
	
	List{SemaVar} active_vars = sec.get_active_vars((int)ctx.offset);

	foreach (var_entry : active_vars)
    {
		VarDecl* decl = var_entry.def.as(VAR_DECL);
        Cursor var_cursor = { .section = ctx.section, .node = var_entry.def };
        String name = var_cursor.spelling(tmem) ?? "";

        if (ctx.prefix.len > 0 && !name.contains(ctx.prefix)) continue;

		Cursor type_cursor = { ctx.section, decl.type };
		String type_name;
		if (decl.type)
		{
			type_name = type_cursor.spelling(tmem) ?? "";
		}
		
        String details;
		CompletionItemKind kind;
		switch (true)
		{
		case decl.flags.is_const:
			kind = CONSTANT;
			details = string::tformat("(constant) %s", type_name);
			break;
		case decl.kind == VAR_GLOBAL:
			kind = VARIABLE;
			details = string::tformat("(global) %s", type_name);
			break;
		case decl.kind == VAR_PARAM:
			kind = VARIABLE;
			details = string::tformat("(param) %s", type_name);
			break;
		case decl.kind == VAR_LOCAL:
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
