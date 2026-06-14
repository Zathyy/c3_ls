module lsp::analysis;

import analyzer::core;

import std::collections::list;

fn String extract_prefix(String text, sz byte_offset)
{
    if (byte_offset == 0 || byte_offset > text.len) return "";

    sz start_idx = byte_offset;
    while (start_idx > 0)
    {
        char c = text[start_idx - 1];
        if (c.is_alnum() || c == '_') {
			start_idx--;
		}
        else {
			break;
		}
    }

    if (start_idx >= byte_offset) return "";
    return text[start_idx..byte_offset];
}

fn CompletionItemKind completion_kind_from_node(Node* node)
{
	NodeKind kind = node.kind;

	switch (kind)
	{
		case MODULE_DECL:    return MODULE;
		case FN_DECL:        return FUNCTION;
		case ENUM_DECL:      return ENUM;
		case INTERFACE_DECL: return INTERFACE;
		case STRUCT_DECL:    return STRUCT;
        case VAR_DECL:
		{
			VarDecl* var_decl = node.as(VAR_DECL);
			if (var_decl.flags.is_const)
			{
				return CONSTANT;
			}
			switch (var_decl.kind)
			{
				case VAR_FIELD:
					return FIELD;
				default:
					return VARIABLE;
			}
		}
		default:
			return TEXT;
	}
}

<*
*>
fn ScopeKind find_scope(Context* ctx, int cursor_pos, Node** enclosing_node)
{
    *enclosing_node = null;

    foreach (node : ctx.section.nodes)
    {
        if (cursor_pos >= node.start_token && cursor_pos <= node.end_token)
        {
            *enclosing_node = node;
    
            switch (node.kind)
            {
                case FN_DECL:
                case MACRO_DECL:
                    return EXECUTION;

                case STRUCT_DECL:
                    return CONTAINER;

                default:
                    break;
            }
        }
    }

    return GLOBAL;
}

fn void inject_type_properties(Context* ctx, List{CompletionItem}* items, NodeKind type_kind)
{
    items.push({ .label = "alignment", .kind = PROPERTY, .detail = "sz", .documentation = "Alignment of the type in bytes." });
    items.push({ .label = "kind", .kind = PROPERTY, .detail = "TypeKind", .documentation = "The underlying kind of the type." });
    items.push({ .label = "name", .kind = PROPERTY, .detail = "String", .documentation = "The short name of the type." });
    items.push({ .label = "qname", .kind = PROPERTY, .detail = "String", .documentation = "The fully qualified name of the type." });
    items.push({ .label = "size", .kind = PROPERTY, .detail = "sz", .documentation = "Size of the type in bytes." });
    items.push({ .label = "typeid", .kind = PROPERTY, .detail = "typeid", .documentation = "The unique type identifier." });
    items.push({ .label = "methods", .kind = PROPERTY, .detail = "any[]", .documentation = "List of methods attached to this type." });

    switch (type_kind)
    {
        case STRUCT_DECL:
            items.push({ .label = "members", .kind = PROPERTY, .detail = "any[]", .documentation = "Array of fields/members." });
            items.push({ .label = "get_tag", .kind = METHOD, .detail = "fn any(String)", .documentation = "Get attributes/tags." });
            items.push({ .label = "has_tag", .kind = METHOD, .detail = "fn bool(String)", .documentation = "Check if attribute exists." });
            if (type_kind == STRUCT_DECL) {
                items.push({ .label = "is_substruct", .kind = PROPERTY, .detail = "bool" });
                items.push({ .label = "parent", .kind = PROPERTY, .detail = "typeid" });
            }
            break;

        case ENUM_DECL:
            items.push({ .label = "values", .kind = PROPERTY, .detail = "any[]", .documentation = "List of all enum variants." });
            items.push({ .label = "len", .kind = PROPERTY, .detail = "sz", .documentation = "Number of elements." });
            items.push({ .label = "members", .kind = PROPERTY, .detail = "any[]" });
            items.push({ .label = "from_ordinal", .kind = METHOD, .detail = "fn type(sz)" });
            items.push({ .label = "lookup_field", .kind = METHOD, .detail = "fn any(String)" });
            break;

        case FN_DECL:
            items.push({ .label = "params", .kind = PROPERTY, .detail = "any[]", .documentation = "Function parameter types." });
            items.push({ .label = "returns", .kind = PROPERTY, .detail = "typeid", .documentation = "Function return type." });
            break;

        default:
            break;
    }
}