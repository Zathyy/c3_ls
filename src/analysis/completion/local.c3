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
        Cursor var_cursor = { .section = ctx.section, .node = var_entry.def };
        String name = var_cursor.spelling(tmem) ?? "";

        if (ctx.prefix.len > 0 && !name.contains(ctx.prefix)) continue;

        String details = string::tformat("(local) %s", name);

        items.push({ 
            .label = name, 
            .kind = VARIABLE, 
            .detail = details,
            .sort_text = string::tformat("0001_%s", name)
        });
    }
}
