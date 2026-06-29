module lsp::analysis::completion;

import analyzer::workspace;
import analyzer::core;
import analyzer::cursor;
import analyzer::sema;

import std::collections::list;
import std::collections::map;

import lsp::core;
import uri;

<*
 check for '.' or '::'
*>
fn void detect_access_context(Context* ctx)
{
	ctx.access = NONE;
	ctx.base_identifier = "";

	if (ctx.tokens.len() < 2) return;

	sz op_idx = -1;
	for (sz i = 0; i < ctx.tokens.len(); i++)
	{
		// If this token starts at or past the cursor, the operator must be the previous one
		if (ctx.tokens[i].pos >= ctx.offset)
		{
			op_idx = i - 1;
			break;
		}
	}
	
	// If the cursor is at the very end of the file, the operator is the last token
	if (op_idx == -1) op_idx = ctx.tokens.len() - 1;
	if (op_idx < 1) return; // Need at least an identifier + operator
	Token op_tok = ctx.tokens[op_idx];
	if (op_tok.kind == DOT || op_tok.kind == SCOPE)
	{
		// Ensure the token right before it is the base identifier
		Token base_tok = ctx.tokens[op_idx - 1];
		switch (base_tok.kind)
		{
			case IDENT:
			case TYPE_IDENT:
			case HASH_IDENT:
			case AT_IDENT:
				ctx.access = (op_tok.kind == SCOPE) ? LspAccessKind.STATIC : LspAccessKind.INSTANCE;
				String src = ctx.section.source_file.source;
				ctx.base_identifier = src[base_tok.pos:base_tok.len];
				ctx.base_offset = base_tok.pos;		
			default:
				break;
		}
	}
}

<*
 @returns "true if this consumed the completion (context locked to member access)"
*>
fn bool provide_member_access(Context* ctx, List{CompletionItem}* items)
{
	if (ctx.access == NONE || ctx.base_identifier.len == 0) return false;
	switch (ctx.access)
	{
		case STATIC:
		{
			List{SymbolEntry}? candidates = ctx.ws.find_symbol_by_name(ctx.base_identifier);
			if (catch candidates) return false;
			if (candidates.len() == 0) return false;
			if (!candidates[0].node) return false;
			analysis::inject_type_properties(ctx, items, candidates[0].node.kind);
			return true;
		}
		case INSTANCE:
		{
			log::debug("acess: %s", "instance");
			List{SemaVar} active_vars = ctx.section.get_active_vars((int)ctx.base_offset);
			Node* var_def = null;

			foreach (var_entry : active_vars)
			{
				Cursor var_cursor = { .section = ctx.section, .node = var_entry.def };
				log::debug("var spelling: %s", var_cursor.spelling(tmem) ?? "");
				if ((var_cursor.spelling(tmem) ?? "") == ctx.base_identifier)
				{
					var_def = var_entry.def;
					break;
				}
			}


			if (!var_def)
			{
				log::debug("Could not find local variable declaration for: %s", ctx.base_identifier);
				return false;
			}

			ModuleSection* section = workspace::get_section_from_node(ctx.ws, var_def);
			if (!section)
			{
				log::debug("Failed to get section from node");
				return false;
			}
		
			Cursor type_cursor = { section, var_def.as(VAR_DECL).type };
			String type_spelling = type_cursor.raw_type_identifier() ?? "";

			log::debug("Checking for type: %s", type_spelling);

			List{SymbolEntry}? candidates = ctx.ws.find_symbol_by_name(type_spelling);
			if (catch candidates) return false;
			if (candidates.len() == 0) return false;
			if (!candidates[0].node) return false;
			
			log::debug("found candidate: %s", candidates[0].node.kind);

			section = workspace::get_section_from_node(ctx.ws, candidates[0].node);
			if (!section)
			{
				log::debug("Failed to get section from node");
				return false;
			}

			if (candidates[0].node.kind == STRUCT_DECL)
            {
                StructDecl* str_decl = candidates[0].node.as(STRUCT_DECL);
                foreach (field_node : str_decl.fields)
                {
                    if (field_node.kind != VAR_DECL) continue;
					VarDecl* field = field_node.as(VAR_DECL);

                    Cursor field_cursor = { section, field_node };
                    String field_name = field_cursor.spelling(tmem) ?? "";

					Cursor field_type_cursor = { section, field.type };
					String field_type_name = field_type_cursor.spelling(tmem) ?? "";

                    if (ctx.prefix.len > 0 && !field_name.contains(ctx.prefix)) continue;
                    
                    items.push({
                        .label = field_name,
                        .kind = FIELD,
                        .detail = field_type_name
                    });
                }
            }
			
			ctx.ws.modules.@each(; name, mod)
			{
				mod.registry.methods.@each(; MethodKey key, List{SymbolEntry} list)
				{
					if COND: (key.type_name == ctx.base_identifier) 
					{
						if (ctx.prefix.len > 0 && !key.method_name.contains(ctx.prefix)) break COND;

						foreach (entry : list) 
						{
							items.push({
								.label = key.method_name,
								.kind = METHOD,
								.detail = string::tformat("method of %s", ctx.base_identifier)
							});
							break;
						}

					}
				};
			};
			
			return true;
		}

		default:
	}
	
	return false;
}