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
			Cursor node_cursor = cursor::find_at(ctx.section, (int)ctx.base_offset);
			log::info("instance: %s", node_cursor.node.kind.description);
			
			if (node_cursor.is_valid())
			{
				switch (node_cursor.node.kind)
				{
					case STRUCT_DECL:
						StructDecl* str_decl = node_cursor.node.as(STRUCT_DECL);
						foreach (field_node : str_decl.fields)
						{
							VarDecl* field = field_node.as(VAR_DECL);
							Cursor cursor = { ctx.section, field_node };
							String field_name = cursor.spelling(tmem) ?? "";

							if (ctx.prefix.len > 0 && !field_name.contains(ctx.prefix)) break;
							
							items.push({
								.label = field_name,
								.kind = FIELD,
								.detail = string::tformat("Field of %s", node_cursor.spelling(tmem) ?? "")
							});
						}
						break;
					default:
						log::warn("Unhandled kind: %s", node_cursor.node.kind.description);
						break;
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