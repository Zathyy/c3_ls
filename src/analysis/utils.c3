module lsp::analysis;

import c3_parser::ast;

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

fn CompletionItemKind completion_kind_from_node(NodeKind kind)
{
	switch (kind)
	{
		case MODULE_DECL:    return MODULE;
		case FN_DECL:        return FUNCTION;
		case ENUM_DECL:      return ENUM;
		case INTERFACE_DECL: return INTERFACE;
		case STRUCT_DECL:    return STRUCT;
		default:
			return TEXT;
	}
}